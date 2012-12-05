/**
 * SubZero, a MDNS browser.
 * Copyright (C) 2012 Daniel Svensson
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

internal class SubZero.ServiceVisitor : BaseDNSRecordVisitor, DNSRecordVisitor
{
	private GLib.HashTable<string,bool> discovered = new HashTable<string,bool>(str_hash, str_equal);

	private Browser browser;

	public ServiceVisitor(SubZero.Browser browser)
	{
		this.browser = browser;
	}

	public new void service_record(string name, string hostname, uint16 port)
	{
		foreach (var service in browser.services) {
			if (name.has_suffix(service) && !discovered.contains(name)) {
				discovered.add(name);
				browser.service_event(service, hostname, port);
				break;
			}
		}
	}
}

public class SubZero.Browser : GLib.Object
{
	private const uint16 MDNS_PORT = 5353;

	private GLib.InetAddress inet_address_any = new GLib.InetAddress.any(GLib.SocketFamily.IPV4);
	// private GLib.InetAddress inet6_address_any = new GLib.InetAddress.any(GLib.SocketFamily.IPV6);

	private GLib.InetAddress inet_address_mdns = new GLib.InetAddress.from_string("224.0.0.251");
	// private GLib.InetAddress inet6_address_mdns = new GLib.InetAddress.from_string("ff02::fb");

	public signal void service_event(string service, string hostname, int port);

	private GLib.Socket server_socket;
	private GLib.Socket client_socket;

	private GLib.IOChannel channel;
	private uint server_source = -1;
	private uint client_source = -1;

	private DNSRecordVisitor visitor;
	private uint8[] query;

	public bool is_running { get; private set; default = false; }
	public uint interval { get; set; default = 10; }
	public string[] services { get; set; default = {}; }

	public Browser()
	{
		visitor = new DebugDNSRecordVisitor(new ServiceVisitor(this));

		this.notify["services"].connect((s, p) => {
			try {
				query = DNS.generate_ptr_query(services);
			} catch (GLib.Error e) {
				GLib.warning("Services produced an illegal query, ignoring.");
			}
		});
		this.notify["interval"].connect((s, p) => {
			if (is_running) {
				GLib.Source.remove(client_source);
				client_source = GLib.Timeout.add_seconds(interval, send_query);
			}
		});
	}

	public void start()
	{
		GLib.assert(!is_running);

		try {
			server_socket = new GLib.Socket(GLib.SocketFamily.IPV4, GLib.SocketType.DATAGRAM, GLib.SocketProtocol.UDP);
			server_socket.multicast_ttl = 225;
			server_socket.multicast_loopback = true;
			server_socket.bind(new GLib.InetSocketAddress(inet_address_mdns, MDNS_PORT), true);
			server_socket.join_multicast_group(inet_address_mdns, false, "lo");

			channel = new IOChannel.unix_new(server_socket.fd);
			server_source = channel.add_watch(IOCondition.IN, on_incoming);

			client_socket = new GLib.Socket(GLib.SocketFamily.IPV4, GLib.SocketType.DATAGRAM, GLib.SocketProtocol.UDP);
			client_socket.bind(new GLib.InetSocketAddress(inet_address_any, MDNS_PORT), true);

			query = DNS.generate_ptr_query(services);
			send_query();

			client_source = GLib.Timeout.add_seconds(interval, send_query);

			is_running = true;
		} catch (GLib.Error e) {
			GLib.warning(@"Could not setup: $(e.message)");
			cleanup();
		}
	}

	public void stop()
	{
		cleanup();
		is_running = false;
	}

	private void cleanup()
	{
		if (client_source != -1)
			GLib.Source.remove(client_source);
		if (server_source != -1)
			GLib.Source.remove(server_source);

		client_source = -1;
		server_source = -1;

		channel = null;

		server_socket = null;
		client_socket = null;
	}

	private bool send_query()
	{
		try {
			client_socket.send_to(new GLib.InetSocketAddress(inet_address_mdns, MDNS_PORT), query);
		} catch (GLib.Error e) {
			GLib.warning(@"Could not send query: $(e.message)");
		}
		return true;
	}
	private bool on_incoming()
	{
		uint8 buffer[9000];

		try {
			var bytes_read = server_socket.receive(buffer);
			GLib.debug(@"received $bytes_read bytes");
			if (bytes_read == 0)
				return true;

			Util.hexdump(buffer[0:bytes_read]);

			DNS.parse(new GLib.DataInputStream(new GLib.MemoryInputStream.from_data (buffer, null)), visitor);
		} catch (GLib.Error e) {
			GLib.warning(@"Could not parse MDNS packet: $(e.message)");
			try {
				GLib.FileIOStream stream;
				GLib.File.new_tmp("packet-XXXXXX.data", out stream);
				stream.get_output_stream().write(buffer);
				GLib.warning(@"Wrote dns packet in $(GLib.Environment.get_tmp_dir())");
			} catch (GLib.Error e2) {
				GLib.warning(@"Could not write debug file: $(e2.message)");
			}
		}

		return true;
	}
}
