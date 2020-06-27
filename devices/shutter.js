const BaseDevice = require('./baseDevice');

class Shutter extends BaseDevice {
  async setState(value) {
    return await this._api.setState({
      devId: this._deviceId,
      command: 'turnOnOff',
      setState: value,
    });
  }
  async stop() {
    return await this._api.setState({
      devId: this._deviceId,
      command: 'startStop',
      setState: 0,
    });
  }
}
module.exports = Shutter;
