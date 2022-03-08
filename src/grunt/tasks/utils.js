/* eslint-disable */
const path = require('path');
const configSource = require('../../config/cordovaDefaultBuildConfig.json');
// const [widgetName] = process.argv.slice(2);
const fs = require('fs');

function createFolder(from, to) {
    const copydir = require('copy-dir');

    copydir.sync(from, to, {
        utimes: true,  // keep add time and modify time
        mode: true,    // keep file mode
        cover: true    // cover file when exists, default is true
    });
}

function replaceInConfigXml(jobId) {
    const configXmlPath = path.join(__dirname, jobId, 'config.xml');
    const configSource = require('../../config/cordovaDefaultBuildConfig.json');
    console.log('configSource: ', configSource);
    fs.readFile(configXmlPath, 'utf8', function (err,data) {
        if (err) {
            return console.log(err);
        }
        console.log('reading config.xml');
        let result = data;
        function replaceInObject(obj, searchPrefix = '') {
            Object.keys(obj).forEach(function(appField){
                if (['string', 'number', 'boolean'].includes(typeof obj[appField])) {
                    var re = new RegExp(`#${searchPrefix}${appField}#`,"g");
                    console.log('replacing: '+ re + ' with: ' + obj[appField]);
                    result = result.replace(re, obj[appField]);
                } else {
                    console.log('typeof ' + appField + ' is not replaceable!');
                }
            });
        }
        replaceInObject(configSource.applicationConfig);
        replaceInObject(configSource.applicationConfig.android, 'android-');
        replaceInObject(configSource.applicationConfig.ios, 'ios-');
        const androidSplashString = configSource.applicationConfig.android.splash.map(function(splashItem){
            return `<splash src="${splashItem.src}" density="${splashItem.density}"/>`;
        }).join('\n\n        ');

        const iosSplashString = configSource.applicationConfig.ios.splash.map(function(splashItem){
            return `<splash src="${splashItem}" />`;
        }).join('\n\n        ');

        const iosIconsString = configSource.applicationConfig.ios.icons.map(function(iconItem){
            return `<icon height="${iconItem.height}" src="${iconItem.src}" width="${iconItem.width}" />`;
        }).join('\n\n');


        result = result.replace(/<!-- iOS-Splash-Placeholder -->/, iosSplashString)
        .replace(/<!-- iOS-Icons-Placeholder -->/, iosIconsString)
        .replace(/<!-- Android-Splash-Placeholder -->/, androidSplashString);
        // const result = data.replace(/WidgetTemplate/g, widgetName);
        fs.writeFile(configXmlPath, result, 'utf8', function (err) {
            if (err) {return console.log(err);}
        });
    });
}

function createNewApp(jobId = 'newApp') {
    console.log('######Starting To Create new Cordova APP######');
    const srcFolder = path.join(__dirname,'../../../', 'appTemplate');
    const targetFolder = path.join(__dirname, jobId);
    createFolder(srcFolder, targetFolder);
    replaceInConfigXml(jobId);
    //TODO - replaceInPackageJson()
}

module.exports = createNewApp;
