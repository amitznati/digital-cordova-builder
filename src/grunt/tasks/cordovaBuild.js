const cordovaBuild = require('./utils');
module.exports = function(grunt) {
    // grunt.loadNpmTasks('grunt-shell');
    // grunt.initConfig({
    //     shell: {
    //         command: [
    //             'npm install bower',
    //             'bower install angular',
    //             'bower install angularjs',
    //             'bower install bootstrap',
    //             'bower install jquery',
    //             'bower install tether'
    //         ].join('&&')
    //     }
    // });
    // grunt.task.registerMultiTask('cordovaBuild', 'Create an application customisation', function () {
    //     uxfmeBuild(this.options());
    // });
    grunt.registerTask('cordovaBuild', cordovaBuild);
};
