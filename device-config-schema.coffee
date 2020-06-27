module.exports = {
  title: "pimatic-tuya device config schemas"
  TuyaSwitch: {
    title: "TuyaSwitch config options"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:{
      deviceId:
        description: "The deviceId of the Tuya device"
        type: "string"
      icon:
        description: "Icon url of the device"
        type: "string"
      statePollingTime:
        description: "The time in milliseconds the status of a Tuya switch is updates/synced"
        type: "number"
        default: 60000
    }
  }
  TuyaShutter: {
    title: "TuyaShutter config options"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:{
      deviceId:
        description: "The deviceId of the Tuya device"
        type: "string"
      icon:
        description: "Icon url of the device"
        type: "string"
      rollingTime:
        description: "Total shutter time in milliseconds to open or close"
        type: "number"
        default: 15000
      statePollingTime:
        description: "The time in milliseconds the status of a Tuya shutter is updates/synced"
        type: "number"
        default: 60000
    }
  }
}
