module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  M = env.matcher
  _ = require('lodash')
  CloudTuya = require('./cloudtuya.js')
  TS = require './devices/switch.js'


  class TuyaPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>

      pluginConfigDef = require './pimatic-tuya-config-schema'

      @deviceConfigDef = require("./device-config-schema")

      @userName = @config.userName
      @password = @config.password
      @countryCode = @config.countryCode
      @bizType = @config.bizType
      @region = @config.region
      @loggedIn = false
      @api = new CloudTuya(
        userName: @userName
        password: @password
        bizType: @bizType
        countryCode: @countryCode
        region: @region
      )
      @api.login()
      .then(() =>
        @loggedIn = true
        #env.logger.info '@api-login: ' + JSON.stringify(@api,null,2)
        env.logger.debug "Login succesful"
        @emit 'loggedIn'
      ).catch((e) =>
        env.logger.error 'Error login api: ' +  e.message
      )

      @framework.deviceManager.registerDeviceClass('TuyaSwitch', {
        configDef: @deviceConfigDef.TuyaSwitch,
        createCallback: (config, lastState) => new TuyaSwitch(config, lastState, @framework, @, @api)
      })

      ###
      @framework.ruleManager.addActionProvider(new DeebotActionProvider(@framework))
      ###


      ###
      TUYA_TYPE_TO_HA = {
          "climate": "climate",
          "cover": "cover",
          "fan": "fan",
          "light": "light",
          "scene": "scene",
          "switch": "switch",
      }
      ###

      @framework.deviceManager.on('discover', (eventData) =>
        @framework.deviceManager.discoverMessage 'pimatic-tuya', 'Searching for new devices'
        @api.find()
        .then((devices) =>
          env.logger.debug "Found devices: " + JSON.stringify(devices,null,2)
          for device in devices
            _newId = device.id
            if _.find(@framework.deviceManager.devicesConfig,(d) => (d.id).indexOf(_newId)>=0)
              env.logger.info "Device '" + _newId + "' already in config"
            else
              _newClass = @selectClass(device.dev_type)
              if _newClass
                config =
                  id: _newId
                  name: device.name
                  class: _newClass
                  icon: device.icon
                  deviceId: device.id
                @framework.deviceManager.discoveredDevice( "Tuya", config.name, config)
              else
                env.logger.debug "Devicetpye '#{device.device_type}' is not yet supported."
        )
        .catch((e) =>
          env.logger.error 'Error find devices: ' +  e
        )
      )

    selectClass: (deviceType) =>
      switch deviceType
        when "switch"
          return "TuyaSwitch"
          #when "shutter"
          #  return "TuyaShutter"
          #when "cover"
          #  return "TuyaShutter"
        else
          return null


  class TuyaSwitch extends env.devices.PowerSwitch

    constructor: (config, lastState, @framework, @plugin, api) ->
      @config = config
      @id = @config.id
      @name = @config.name
      #@_state = lastState?.state?.value or off

      @deviceId = @config.deviceId
      @api = api

      @statePollingTime = if @config.statePollingTime? then @config.statePollingTime else 60000

      @framework.variableManager.waitForInit()
      .then(()=>
        @tuyaSwitch = new TS(
          api: @api
          deviceId: @deviceId
          )
        @plugin.loggedIn = true
        #env.logger.info "Switch: " + JSON.stringify(@tuyaSwitch,null,2)
        updateState()
      )

      @plugin.on 'loggedIn', @loginStatus = () =>
        @tuyaSwitch = new TS(
          api: @api
          deviceId: @deviceId
          )
        ###
        @tuyaSwitch.getSkills()
        .then((s)=>
          env.logger.debug "Skills: " + JSON.stringify(s,null,2)
        )
        ###
        updateState()


      updateState = () =>
        @tuyaSwitch.state()
        .then((s) =>
          env.logger.debug "state " + JSON.stringify(s,null,2)
          if s is "ON" then _s = on else _s = off
          return @changeStateTo(_s)
        )
        .then(()=>
          @updateTimer = setTimeout(updateState, @statePollingTime)
        )
        .catch((err)=>
          env.logger.debug "Error handled updateState: " + err
          @updateTimer = setTimeout(updateState, 10000)
        )

      super()

    getState: () ->
      if @_destroyed or not @tuyaSwitch?
        return Promise.resolve @_state
      else
        #env.logger.info "ok"
        return @tuyaSwitch.isOn()
        .then((_switchState)=>
          return Promise.resolve @_state
        )

    changeStateTo: (state) ->
      if @_destroyed or not @tuyaSwitch?
        return Promise.resolve()
      else
        if state is true
          @tuyaSwitch.turnOn()
          .then(()=>
            env.logger.debug "Turned on"
            @_setState(on)
            return Promise.resolve()
          )
        else
          @tuyaSwitch.turnOff()
          .then(()=>
            env.logger.debug "Turned off"
            @_setState(off)
            return Promise.resolve()
          )


    destroy:() =>
      #@removeListener 'loggedIn', @loginStatus
      clearTimeout(@updateTimer)
      #@tuyaSwitch = null
      super()

  ###

  class DeebotActionProvider extends env.actions.ActionProvider

    constructor: (@framework) ->

    parseAction: (input, context) =>

      beebotDevice = null
      @speed = 2
      @waterlevel = 1
      @roomsArray = []
      @roomsStringVar = null
      @waterStringVar = null
      @area = 
        x1: 0
        y1: 0
        x2: 0
        y2: 0
      @areaStringVar = null
      @cleanings = 1
      @cleaningsStringVar = null

      deebotDevices = _(@framework.deviceManager.devices).values().filter(
        (device) => device.config.class == "DeebotDevice"
      ).value()

      setCommand = (command) =>
        @command = command

      addSpeed = (m,tokens) =>
        unless tokens>0 and tokens<5
          context?.addError("Speed must be 1, 2, 3 or 4.")
          return
        setCommand("speed")
        @speed = Number tokens


      addRoom = (m,tokens) =>
        unless tokens >=0
          context?.addError("Roomnumber should 0 or higher.")
          return
        @roomsArray.push Number tokens
        setCommand("cleanroom")

      addWaterlevel = (m,tokens) =>
        unless tokens>0 and tokens<5
          context?.addError("Waterlevel must be 1, 2, 3 or 4.")
          return
        setCommand("waterlevel")
        @waterlevel = Number tokens

      roomString = (m,tokens) =>
        unless tokens?
          context?.addError("No variable")
          return
        @roomsStringVar = tokens
        setCommand("cleanroom")
        return

      speedString = (m,tokens) =>
        unless tokens?
          context?.addError("No variable")
          return
        @speedStringVar = tokens
        setCommand("speed")
        return

      waterlevelString = (m,tokens) =>
        unless tokens?
          context?.addError("No variable")
          return
        @waterStringVar = tokens
        setCommand("waterlevel")
        return

      addAreaX1 = (m,tokens) =>
        @area.x1 = tokens
        setCommand("cleanarea")
      addAreaY1 = (m,tokens) =>
        @area.y1 = tokens
        setCommand("cleanarea")
      addAreaX2 = (m,tokens) =>
        @area.x2 = tokens
        setCommand("cleanarea")
      addAreaY2 = (m,tokens) =>
        @area.y2 = tokens
        setCommand("cleanarea")

      areaString = (m,tokens) =>
        unless tokens?
          context?.addError("No variable")
          return
        @areaStringVar = tokens
        setCommand("cleanroom")
        return

      addCleanings = (m,tokens) =>
        env.logger.info "Cleanings " + tokens
        unless (Number tokens) == 1 or (Number tokens) == 2
          context?.addError("Cleanings should be 1 or 2.")
          return
        @cleanings = tokens
        setCommand("cleanarea")

      cleaningsString = (m,tokens) =>
        unless tokens?
          context?.addError("No variable")
          return
        @cleaningsStringVar = tokens
        setCommand("cleanarea")
        return


      m = M(input, context)
        .match('deebot ')
        .matchDevice(deebotDevices, (m, d) ->
          # Already had a match with another device?
          if beebotDevice? and deebotDevices.id isnt d.id
            context?.addError(""""#{input.trim()}" is ambiguous.""")
            return
          beebotDevice = d
        )
        .or([
          ((m) =>
            return m.match(' clean', (m) =>
              setCommand('clean')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' clean')
              .or([
                ((m) =>
                  return m.match(' [')
                    .matchNumber(addRoom)
                    .match(']')
                ),
                ((m) =>
                  return m.match(' ')
                    .matchVariable(roomString)
                )
              ])
          ),
          ((m) =>
            return m.match(' cleanarea ')
              .or([
                ((m) =>
                  return m.match('[')
                    .matchNumber(addAreaX1)
                    .match(",")
                    .matchNumber(addAreaY1)
                    .match(",")
                    .matchNumber(addAreaX2)
                    .match(",")
                    .matchNumber(addAreaY2)
                    .match(']')
                ),
                ((m) =>
                  return m.matchVariable(areaString)
                )
              ])
              .match(' cleanings ')
                .or([
                  ((m) =>
                    return m.matchNumber(addCleanings)
                  ),
                  ((m) =>
                    return m.matchVariable(cleaningsString)
                  )
                ])
          ),
          ((m) =>
            return m.match(' pause', (m) =>
              setCommand('pause')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' resume', (m) =>
              setCommand('resume')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' stop', (m) =>
              setCommand('stop')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' charge', (m)=>
              setCommand('charge')
              match = m.getFullMatch()
            )
          ),
          ((m) =>
            return m.match(' speed ')
              .or([
                ((m) =>
                  return m.matchNumber(addSpeed)
                ),
                ((m) =>
                  return m.matchVariable(speedString)
                )
              ])
          ),
          ((m) =>
            return m.match(' waterlevel ')
              .or([
                ((m) =>
                  return m.matchNumber(addWaterlevel)
                ),
                ((m) =>
                  return m.matchVariable(waterlevelString)
                )
              ])
          )
        ])

      #@rooms = @roomsArray
      #convert rooms array into comma seperated string (list)
      @rooms = ""
      for room,i in @roomsArray
        @rooms += room
        if i < @roomsArray.length - 1
          @rooms += ", "
      #@rooms += ")"
      #env.logger.debug "command " + @command + ", Roomlist " + @rooms

      match = m.getFullMatch()
      if match? #m.hadMatch()
        env.logger.debug "Rule matched: '", match, "' and passed to Action handler"
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new DeebotActionHandler(@framework, beebotDevice, @command, @rooms, @roomsStringVar, @speed,  
            @speedStringVar, @waterlevel, @waterStringVar, @area, @areaStringVar, @cleanings, @cleaningsStringVar)
        }
      else
        return null


  class DeebotActionHandler extends env.actions.ActionHandler

    constructor: (@framework, @beebotDevice, @command, @rooms, @roomsStringVar, @speed, 
      @speedStringVar, @waterlevel, @waterStringVar, @area, @areaStringVar, @cleanings, @cleaningsStringVar) ->

    executeAction: (simulate) =>
      if simulate
        return __("would have cleaned \"%s\"", "")
      else
        if @roomsStringVar?
          _var = @roomsStringVar.slice(1) if @roomsStringVar.indexOf('$') >= 0
          _rooms = @framework.variableManager.getVariableValue(_var)
          unless _rooms?
            return __("\"%s\" Rule not executed, #{_rooms} is not a valid room string", "")
          _roomArr = (String _rooms).split(',')
          newRooms = ""
          for room,i in _roomArr
            _room = (room.trimLeft()).trimEnd()
            if Number.isNaN(Number _room) or Number _room < 0 or not (room?) or room is ""
              return __("\"%s\" Rule not executed, #{_rooms} is not a valid room string", "")
            if i > 0 then newRooms = newRooms + " "
            newRooms = newRooms + _room
            if i < (_roomArr.length - 1) then newRooms = newRooms + ","
        else
          newRooms = @rooms

        if @speedStringVar?
          _var = @speedStringVar.slice(1) if @speedStringVar.indexOf('$') >= 0
          _speed = @framework.variableManager.getVariableValue(_var)
          unless _speed?
            return __("\"%s\" Rule not executed, #{_speed} is not a valid variable", "")
          if Number.isNaN(Number _speed) or Number _speed < 1 or Number _speed > 4
            return __("\"%s\" Rule not executed, #{_speed} is not a valid speed value", "")
          newSpeed = _speed
        else
          newSpeed = @speed

        if @waterStringVar?
          _var = @waterStringVar.slice(1) if @waterStringVar.indexOf('$') >= 0
          _waterlevel = @framework.variableManager.getVariableValue(_var)
          unless _waterlevel?
            return __("\"%s\" Rule not executed, #{_waterlevel} is not a valid variable", "")
          if Number.isNaN(Number _waterlevel) or Number _waterlevel < 1 or Number _waterlevel > 4
            return __("\"%s\" Rule not executed, #{_waterlevel} is not a valid waterlevel value", "")
          newWaterlevel = _waterlevel
        else
          newWaterlevel = @waterlevel

        if @areaStringVar?
          _var = @areaStringVar.slice(1) if @areaStringVar.indexOf('$') >= 0
          _area = @framework.variableManager.getVariableValue(_var)
          unless _area?
            return __("\"%s\" Rule not executed, #{_area} is not a valid area string", "")
          _coordsArr = (String _area).split(',')
          newArea = ""
          for coord,i in _coordsArr
            _coord = (coord.trimLeft()).trimEnd()
            if Number.isNaN(Number _coord)
              return __("\"%s\" Rule not executed, #{_coord} is not a valid coordinate number", "")
            if i > 0 then newArea = newArea + " "
            newArea = newArea + _coord
            if i < (_coordsArr.length - 1) then newArea = newArea + ","
        else
          newArea = @area.x1 + ", " + @area.y1 + ", " + @area.x2 + ", " + @area.y2

        if @cleaningsStringVar?
          _var = @cleaningsStringVar.slice(1) if @cleaningsStringVar.indexOf('$') >= 0
          _cleanings = @framework.variableManager.getVariableValue(_var)
          unless _cleanings?
            return __("\"%s\" Rule not executed, #{_cleanings} does not excist", "")
          if Number.isNaN(Number _cleanings) or Number _cleanings < 1 or Number _cleanings > 2
            return __("\"%s\" Rule not executed, #{_cleanings} is not a valid cleanings value", "")
          newCleanings = _cleanings
        else
          newCleanings = @cleanings

        @beebotDevice.execute(@command, newRooms, newSpeed, newWaterlevel, newArea, newCleanings)
        .then(()=>
          return __("\"%s\" Rule executed", @command)
        ).catch((err)=>
          return __("\"%s\" Rule not executed", "")
        )

  ###


  tuyaPlugin = new TuyaPlugin
  return tuyaPlugin