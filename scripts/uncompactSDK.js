module.exports = function(context) {
    var IosSDKFile = "OpenTok-iOS-2.11.3.tar.bz2";

    exec('tar -zxvf ./' + context.opts.plugin.dir + '/src/ios/' + IosSDKFile, function(err, out, code) {
        console.log('expanded');
    });

    return deferral.promise;
};