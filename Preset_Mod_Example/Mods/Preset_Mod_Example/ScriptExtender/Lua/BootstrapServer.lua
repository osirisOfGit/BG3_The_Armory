-- In your MCM-integrated mod's code
Ext.ModEvents.Armory["TransmogCompleted"]:Subscribe(function(payload)
    _D(string.format("Received TransmogCompleted event with %s", Ext.Json.Stringify(payload)))
end)
