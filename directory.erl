-module(directory).
-export([lookupphone/1, lookupmail/1]).

lookupphone("9532") ->
    "Magnus Ahltorp";

lookupphone("9516") ->
    "Ragnar Sundblad";

lookupphone(Phone) ->
    "Okänd".

ldapsearch(Mail) ->
    {ok, Handle} = eldap:open(["ldap.kth.se"], []),
    ok = eldap:simple_bind(Handle, "dc=kth, dc=se", ""),
    Filter = eldap:equalityMatch("mail", Mail),
    {ok, Result} = eldap:search(Handle, [{base, "dc=kth, dc=se"},
					 {filter, Filter},
					 {attributes,["uid"]}]),
    eldap:close(Handle),
    {eldap_search_result, List, _} = Result,
    case List of
	[] ->
	    none;
	[{eldap_entry, _, Attributes} | _] ->
	    {value, {"uid", [Uid | _]}} = lists:keysearch("uid", 1, Attributes),
	    Uid
    end.

do_recv(Sock, Text) ->
    receive
	{tcp, Sock, Data} ->
	    do_recv(Sock, Text ++ Data);
	{tcp_closed, Sock} ->
	    Text
    end.

lookupkthid(KTHid) ->
    Server = "yorick.admin.kth.se",
    {ok, Sock} = gen_tcp:connect(Server, 80, 
				 [list, {packet, 0}]),
    ok = gen_tcp:send(Sock, "GET /service/personsokning/kthid2tele.asp?kthid=" ++ KTHid ++ " HTTP/1.0\r\n\r\n"),
    
    Text = do_recv(Sock, ""),
    {Header, Body} = sippacket:parse_packet(Text),
    {Request, Headerkeylist} = sippacket:parseheader(Header),
    ok = gen_tcp:close(Sock),
    Numbers = string:tokens(Body, "\r\n"),
    case Numbers of
	[] ->
	    none;
	[Number | _] ->
	    Number
    end.

lookupmail(Mail) ->
    case ldapsearch(Mail ++ "@kth.se") of
	none ->
	    lookupkthid(Mail);
	KTHid ->
	    lookupkthid(KTHid)
    end.