module.exports = function(context) {
    var IosSDKFile = "OpenTok-iOS-2.11.3.tar.bz2";

    var exec = require('./exec/exec.js'),
        Q = context.requireCordovaModule('q'),
        deferral = new Q.defer();

    var sdkdir = context.opts.plugin.dir + '/src/ios/';

    var sdkfile = sdkdir + IosSDKFile

    console.log(sdkfile);

    exec('tar -zxvf ' + sdkfile + ' -C ' + sdkdir, function(err, out, code) {
        console.log('expanded');
        console.log(err);
        console.log(out);
    });

    return deferral.promise;
};