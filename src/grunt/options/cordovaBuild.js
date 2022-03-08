module.exports = {
  options: {
    externalConfigDir: '<%= appConfig.assetsConfigPath %>',
    publicationDir: '.',
    outputDir: '<%= cordovaBuild.options.publicationDir %>/output',
    buildDir: '<%= cordovaBuild.options.outputDir %>/.build',
    provDir: '<%= cordovaBuild.options.outputDir %>/prov',
    appVersion: '<%= package.version %>',
    embeddedFiles: 'WebContent'
  },
  dist: {}
};
