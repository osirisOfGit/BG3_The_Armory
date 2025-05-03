Ext.ModEvents.Armory["TransmogCompleted"]:Subscribe(function(payload)
    _D(string.format("Received TransmogCompleted event with %s", Ext.Json.Stringify(payload)))
end)

Ext.ModEvents.Armory["TransmogRemoved"]:Subscribe(function(payload)
    _D(string.format("Received TransmogRemoved event with %s", Ext.Json.Stringify(payload)))
end)
