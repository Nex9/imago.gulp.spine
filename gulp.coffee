gulp            = require 'gulp'
browserSync     = require 'browser-sync'
reload          = browserSync.reload

coffee          = require 'gulp-coffee'
coffeelint      = require 'gulp-coffeelint'

concat          = require 'gulp-concat'

jade            = require 'gulp-jade'
plumber         = require 'gulp-plumber'
prefix          = require 'gulp-autoprefixer'
stylus          = require 'gulp-stylus'
sass            = require 'gulp-ruby-sass'
uglify          = require 'gulp-uglify'
modRewrite      = require 'connect-modrewrite'

common          = require 'gulp-commonjs'
rename          = require 'gulp-rename'
insert          = require 'gulp-insert'
sourcemaps      = require 'gulp-sourcemaps'
watch           = require 'gulp-watch'
notification    = require 'node-notifier'
exec            = require('child_process').exec

updateNotifier  = require 'update-notifier'
utils           = require './themeutils'
pkg             = require './package.json'
config          = require '../../gulp'

updateNotifier({packageName: pkg.name, packageVersion: pkg.version}).notify()

dest = config.dest
src  = config.src

gulp.task 'modules', ->
  files = (require.resolve(module) for module in config.paths.modules)
  gulp.src(files, base: __dirname)
    .pipe plumber(
      errorHandler: utils.reportError
    )
    .pipe rename (path) ->
      path.extname = ""
      path.dirname = path.dirname.split('node_modules/')[1] if path.dirname.split('node_modules/').length > 1
      path.dirname = path.dirname.split('../')[1] if path.dirname.split('../').length > 1
      path.basename = '' if path.basename is 'index'
      path.dirname = '' if path.basename in ['spine', path.dirname]
      path
    .pipe common()
    .pipe concat config.targets.modules
    .pipe gulp.dest dest

gulp.task 'jade', ->
  gulp.src config.paths.jade
    .pipe plumber(
      errorHandler: utils.reportError
    )
    .pipe jade(client: true).on('error', utils.reportError)
    .pipe insert.prepend "module.exports = "
    .pipe rename extname: ""
    .pipe common()
    .pipe concat config.targets.jade
    .pipe gulp.dest dest

gulp.task 'scripts', ->
  gulp.src config.paths.js
    .pipe plumber(
      errorHandler: utils.reportError
    )
    .pipe rename extname: ""
    .pipe common()
    .pipe concat config.targets.scripts
    .pipe gulp.dest dest

gulp.task 'coffee', ->
  gulp.src config.paths.coffee
    .pipe plumber(
      errorHandler: utils.reportError
    )
    .pipe coffeelint()
    .pipe coffee(bare: true).on('error', utils.reportError)
    .pipe rename extname: ""
    .pipe common()
    .pipe concat config.targets.coffee
    .pipe gulp.dest dest

generateStylus = (production = false) ->
  gulp.src config.paths.stylus
    .pipe plumber(
      errorHandler: utils.reportError
    )
    .pipe stylus({errors: true, use: ['nib'], set:['compress']})
    .pipe prefix('last 4 versions')
    .pipe concat config.targets.css
    .pipe gulp.dest dest
    .pipe reload({stream:true})

gulp.task 'stylus', generateStylus

generateSass = (production = false) ->
  return sass(config.paths.sass, quiet: true, "sourcemap=none": true)
    .pipe plumber
      errorHandler: utils.reportError
    .pipe prefix("last 4 versions")
    .pipe concat config.targets.css
    .pipe plumber.stop()
    .pipe gulp.dest config.dest
    .pipe browserSync.reload(stream:true)

gulp.task 'sass', generateSass

gulp.task 'libs', ->
  gulp.src config.paths.libs
    .pipe concat config.targets.lib
    .pipe gulp.dest dest

gulp.task 'js', ['libs', 'modules', 'scripts', 'coffee', 'jade'], (next) ->
  next()

minifyJs = ->
  gulp.src "#{dest}/#{config.targets.js}"
    .pipe uglify()
    .pipe gulp.dest dest

gulp.task 'minify', ['prepare'], minifyJs

combineJs = (production = false) ->
  # We need to rethrow jade errors to see them
  rethrow = (err, filename, lineno) -> throw err
  files = [
    config.targets.lib
    config.targets.modules
    config.targets.scripts
    config.targets.coffee
    config.targets.jade
  ]
  sources = files.map (file) -> "#{dest}/#{file}"

  gulp.src sources
    .pipe sourcemaps.init()
    .pipe concat config.targets.js
    .pipe insert.append "jade.rethrow = #{rethrow.toLocaleString()};"
    .pipe sourcemaps.write './maps'
    .pipe gulp.dest dest
    .pipe browserSync.reload {stream:true}

gulp.task 'combine', combineJs

gulp.task 'prepare', ['sass', 'stylus', 'js'], combineJs

gulp.task 'watch', ['prepare', 'browser-sync'], ->

  watch
    glob: '**/*.sass', emitOnGlob: false
  , ->
    gulp.start('sass')

  watch
    glob: '**/*.styl', emitOnGlob: false
  , ->
    gulp.start('stylus')

  watch
    glob: config.paths.jade, emitOnGlob: false
  , ->
    gulp.start('jade')

  watch
    glob: config.paths.coffee, emitOnGlob: false
  , ->
    gulp.start('coffee')

  watch
    glob: config.paths.nexDev, emitOnGlob: false
  , ->
    gulp.start('modules')

  watch
    glob: config.paths.js, emitOnGlob: false
  , ->
    gulp.start('scripts')

  files = [config.targets.jade, config.targets.coffee, config.targets.scripts, config.targets.modules]
  sources = ("#{dest}/#{file}" for file in files)

  watch
    glob: sources, emitOnGlob: false
  , ->
    gulp.start('combine')


gulp.task 'build', ['minify'], ->
  generateSass()
  generateStylus()
  # minifyJs()

gulp.task 'deploy', ['build'], ->
  exec 'deploy .', (error, stdout, stderr) ->
    console.log 'result: ' + stdout
    console.log 'exec error: ' + error  if error isnt null

gulp.task 'browser-sync', ->
  browserSync.init ["#{dest}/index.html"],
    server:
      baseDir: "#{dest}"
      middleware: [
        modRewrite ['^([^.]+)$ /index.html [L]']
      ]
    debugInfo: false
    notify: false


gulp.task 'default', ['watch']
