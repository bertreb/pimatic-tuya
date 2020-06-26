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
    }
  }
}
