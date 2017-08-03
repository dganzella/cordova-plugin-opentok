module.exports = function(context) {
    var IosSDKFile = "OpenTok-iOS-2.11.3.tar.bz2";

    var exec = require('./exec/exec.js'),
        Q = context.requireCordovaModule('q'),
        deferral = new Q.defer();

    exec('tar -zxvf ./' + context.opts.plugin.dir + '/src/ios/' + IosSDKFile, function(err, out, code) {
        console.log('expanded');
    });

    return deferral.promise;
};