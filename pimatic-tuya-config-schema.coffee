# #pimatic-tuya configuration options
module.exports = {
  title: "pimatic-tuya configuration options"
  type: "object"
  properties:
    userName:
      descpription: "The username for your Tuya account"
      type: "string"
    password:
      descpription: "The password for your Tuya account"
      type: "string"
    bizType:
      descpription: "The bizType"
      type: "string"
      enum: ["tuya","smart_life","jinvoo_smart"]
    countryCode:
      descpription: "Your country calling code like '31'"
      type: "string"
    region:
      descpription: "Your regioon code like 'eu'"
      type: "string"
      enum: ["az","ay","eu","us"]
      default: "eu"
    debug:
      description: "Debug mode. Writes debug messages to the pimatic log, if set to true."
      type: "boolean"
      default: false
}
