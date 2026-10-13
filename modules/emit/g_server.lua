w.require("emit", true)

-- ⚠️ There is deliberately no "w_lib:server:emit:dispatch" net event any more (removed 2026-10-14).
--    It relayed any event name a client chose to any player it chose (-1 included), with no check.
--    Paired with "w_lib:emit:client:redirect" on every client, one player could make every other
--    client - an admin's among them - send a server event in its own name: WCore:CallCommand
--    givemoney / addpermission ran with the admin's ACE. Nothing in resources/ ever called it
--    (the client-side w.emit.triggerClient that used it was already marked unsafe and deprecated).
--    Client -> other clients must go through a server event that decides who receives what.
