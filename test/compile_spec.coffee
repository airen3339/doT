assert  = require 'assert'
doT     = require '../do_t'
compile = require '../compile'
global.doT    = doT
doT.autoload  = doT.constructor.autoloadFail

dir = require('fs').realpathSync __dirname

describe 'compile', ->
  beforeEach ->
    doT.setCached {}

  it 'invokes callback with err if there is no file', (done) ->
    compile files: ["#{dir}/tmpl/fail"], (err, data) ->
      assert.notEqual err, null
      done()

  it 'invokes callback if empty fileset is given', (done) ->
    compile files: [], (err, data) ->
      assert.equal err, null
      done()

  it 'invokes callback if there is empty folder', (done) ->
    compile files: ["#{dir}/tmpl/empty"], (err, data) ->
      assert.equal err, null
      done()

  it 'compiles file', (done) ->
    compile files: ["#{dir}/tmpl/one.tmpl"], (err, data) ->
      assert.equal err, null
      assert.equal 'one hi', doT.render 'one', val: 'hi'
      done()

  it 'compiles directory', (done) ->
    compile files: ["#{dir}/tmpl/dir"], (err, data) ->
      assert.equal err, null
      assert.equal 'two hi', doT.render 'two', val: 'hi'
      done()

  it 'uses `base` parametr', (done) ->
    compile files: ["#{dir}/tmpl/dir"], base: "#{dir}/tmpl", (err, data) ->
      assert.equal err, null
      assert.equal 'two hi', doT.render 'dir.two', val: 'hi'
      done()

  context 'when filename ends with', ->
    context '`.haml`', ->
      it 'precompiles using haml', (done)->
        compile files: ["#{dir}/tmpl/haml"], (err, data) ->
          assert.equal err, null
          assert.equal '<html>hi</html>', doT.render 'test', val: 'hi'
          done()
      context 'and ruby_server is true', ->
        it 'precompiles using ruby server', (done)->
          @timeout 5000
          compile
            ruby_server: true
            files: ["#{dir}/tmpl/haml"]
            base: "#{dir}/tmpl/haml"
            (err, data) ->
              assert.equal err, null
              assert.equal '<html>hi</html>', doT.render 'test', val: 'hi'
              done()
