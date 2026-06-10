--[[----------------------------------------------------------------------------
	Example module body (client-only).

	Demonstrates a cl_ file loading only on the client, and driving the net
	wrapper. Run `swrp_example_ping` in the client console to fire a
	validated round-trip; watch console for the server's reply.
------------------------------------------------------------------------------]]

concommand.Add( "swrp_example_ping", function( ply, cmd, args )
	local message = table.concat( args, " " )
	if message == "" then message = "hello from client" end

	SWRP.Net.Send( "swrp.example.ping", { message = message } )
end )
