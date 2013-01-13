###
  doT.js
  2011, Laura Doktorova, https://github.com/olado/doT
  
  doT.js is an open source component of http://bebedo.com
  Licensed under the MIT license.
###
"use strict";

startend =
  append:
    start:  "'+("
    end:    ")+'"
    startencode: "'+doT.eh("
  split:
    start:  "';out+=("
    end:    ");out+='"
    startencode: "';out+=doT.eh("
  
doT =
  version:  '0.2.0'
  templateSettings:
    use:          /\{\{#([\s\S]+?)\}\}/g
    define:       /\{\{##\s*([\w\.$]+)\s*(\:|=)([\s\S]+?)#\}\}/g
    varname:      'it'
    strip:        true
    with:         true
    dynamicList:  'it._dynamic'
    startend:     startend.append
  startend: startend
  tags:     {}

cache = {}
sid   = 0 # sequental id for variable names
skip  = /$^/

# tags definition
tags = doT.tags
tags.interpolate =
  regex: /\{\{=([\s\S]+?)\}\}/g
  func: (m, code) ->
    cse = doT.templateSettings.startend
    cse.start + unescape(code) + cse.end

tags.encode =
  regex: /\{\{!([\s\S]+?)\}\}/g
  func: (m, code) ->
    cse = doT.templateSettings.startend
    cse.startencode + unescape(code) + cse.end

tags.conditional =
  regex: /\{\{\?(\?)?\s*([\s\S]*?)\s*\}\}/g
  func: (m, elsecase, code) ->
    if elsecase
      if code
        "' ; } else if ( #{unescape(code)} ) { out += '"
      else
        "'; } else { out += '"
    else
      if code
        "'; if ( #{unescape(code)} ) { out += '"
      else
        "'; } out += '"

tags.iterate =
  regex: /\{\{~\s*(?:\}\}|([\s\S]+?)\s*\:\s*([\w$]+)\s*(?:\:\s*([\w$]+))?\s*\}\})/g
  func: (m, iterate, vname, iname) ->
    if !iterate
      return "'; } } out += '"
    sid += 1
    indv = iname || 'i' + sid
    iterate = unescape iterate
    return "';
      var arr#{sid} = #{iterate};
      if( arr#{sid} ) {
        var #{vname}, #{indv} = -1, l#{sid} = arr#{sid}.length-1;
        while( #{indv} < l#{sid} ){
          #{vname} = arr#{sid}[#{indv} += 1];
          out += '"

tags.iterateFor =
  regex: /\{\{:\s*(?:\}\}|([\s\S]+?)\s*\:\s*([\w$]+)\s*(?:\:\s*([\w$]+))?\s*\}\})/g
  func: (m, iterate, vname, iname) ->
    if !iterate
      return "'; } } out += '"
    sid += 1;
    inpname = 'iter' + sid;
    return "';
      var #{inpname} = #{iterate};
      if ( #{inpname} ) {
        var #{vname}, #{iname};
        for (#{iname} in #{inpname} ) {
          #{vname} = #{inpname}[ #{iname} ];
          out += '"

tags.content_for =
  regex: /\{\{>\s*([\s\S]*?)\s*\}\}/g
  func: (m, id) ->
    if id
      "';
      many_contents = true;
      contents[current_out] = out;
      out_stack.push(current_out);
      current_out='#{unescape(id)}'.trim();
      out = contents[current_out] = '"
    else
      "';
      contents[current_out] = out;
      out = contents[current_out = out_stack.pop()] += '"

tags.xx_includeDynamic =
  regex: /\{\{@@([\S]+?)\([\s]*([\s\S]*?)[\s]*\)\}\}/g
  func: (m, tmpl, args) ->
    sid += 1
    vname = 'tmpl' + sid
    return "';
      var #{vname} = #{doT.templateSettings.dynamicList}[ '#{unescape(tmpl)}' ];
      if ('string' === typeof #{vname}) #{vname} = {name: #{vname}};
      out += doT.render({name: #{vname}.name, args: #{vname}.args || arguments}) + '"

tags.xy_render =
  regex: /\{\{@([\S]+?)\([\s]*([\s\S]*?)[\s]*\)\}\}/g
  func: (m, tmpl, args) ->
    "' + doT.render( '#{tmpl}' #{if args then ",#{unescape(args)}" else ''} ) + '"

tags.zz_evaluate =
  regex: /\{\{([\s\S]+?)\}\}/g
  func: (m, code) ->
    "'; #{unescape(code)}; out += '"

# register in global scope
if (typeof module != 'undefined' && module.exports)
  module.exports = doT
else if (typeof define == 'function' && define.amd)
  define -> doT
else
  #@doT = doT

# helpers
encodeHTMLSource = ->
  encodeHTMLRules =  "&": "&#38;", "<": "&#60;", ">": "&#62;", '"': '&#34;', "'": '&#39;', "/": '&#47;'
  matchHTML = /&(?!#?\w+;)|<|>|"|'|\//g
  (code) ->
    if code
      code.toString().replace( matchHTML, (m) -> encodeHTMLRules[m] || m )
    else
      code

doT.encodeHTML = encodeHTMLSource()
doT.eh = doT.encodeHTML # shortcut

unescape = (code) ->
  code.replace( /\\('|\\)/g, "$1" ).replace( /[\r\t\n]/g, ' ' )
doT.unescape = unescape

# template compilation
resolveDefs = (c, block, def) ->
  (
    (if (typeof block is "string") then block else block.toString())
  ).replace(c.define or skip, (m, code, assign, value) ->
    code = code.substring(4)  if code.indexOf("def.") is 0
    unless code of def
      if assign is ":"
        if c.defineParams
          value.replace c.defineParams, (m, param, v) ->
            def[code] =
              arg: param
              text: v

        def[code] = value  unless code of def
      else
        new Function("def", "def['" + code + "']=" + value) def
    ""
  ).replace c.use or skip, (m, code) ->
    if c.useParams
      code = code.replace(c.useParams, (m, s, d, param) ->
        if def[d] and def[d].arg and param
          rw = (d + ":" + param).replace(/'|\\/g, "_")
          # gtksourceview '
          def.__exp = def.__exp or {}
          def.__exp[rw] = def[d].text.replace(new RegExp("(^|[^\\w$])#{def[d].arg}([^\\w$])", "g"), "$1#{param}$2")
          s + "def.__exp['#{rw}']"
      )
    v = new Function("def", "return " + code)(def)
    (if v then resolveDefs(c, v, def) else v)

doT.compile = (tmpl, def) ->
  c = doT.templateSettings
  str = if (c.use || c.define) then resolveDefs(c, tmpl, def || {}) else tmpl

  if c.strip
    str = str.replace( /(^|\r|\n)\t* +| +\t*(\r|\n|$)/g , ' ' )
      .replace( /\r|\n|\t|\/\*[\s\S]*?\*\//g, '' )
  str = str.replace /'|\\/g, '\\$&'
  # gtksourceview '
  taglist = Object.keys(doT.tags).sort()
  for t_id, t_name of taglist
    str = str.replace doT.tags[ t_name ].regex, doT.tags[ t_name ].func
  str = "
    var out_stack = [], contents = {}, many_contents = false,
      current_out = '_content', out = '#{str}';
    return many_contents ? contents : out;
  "
    .replace( /\n/g, '\\n' )
    .replace( /\t/g, '\\t' )
    .replace( /\r/g, '\\r' )
    .replace( /(\s|;|}|^|{)out\+='';/g, '$1' )
    .replace( /\+''/g, '' )
    .replace( /(\s|;|}|^|{)out\+=''\+/g, '$1out+=' )
  if c.with
    str = "with(#{if true == c.with then c.varname else c.with}) {#{str}}"
  try
    new Function c.varname, str
  catch e
    throw "#{e} in #{str}"

# backward compability
doT.template = doT.compile

# cache functions
doT.getCached = -> cache
doT.setCached = (fns) -> cache = fns
doT.exportCached = ->
  str = ""
  for id, f of cache
    str += ",\"#{id}\": #{f.toString()}"
  "{#{str.substring(1)}}"
doT.addCached = (id, fn) ->
  if 'object' == typeof id
    for i, f of id
      doT.addCached i, f
    return
  cache[id] = fn
  
# doT.render() for transparent autoloding & caching
doT.render = (tmpl) ->
  ('object' != typeof tmpl) && (tmpl = { name: tmpl })
  if !cache[tmpl.name]
    src = doT.autoload tmpl.name
    if false == src
      throw "Template not found: #{tmpl.name}"
    doT.addCached tmpl.name, doT.compile src
  cache[tmpl.name].apply( this, tmpl.args || Array.prototype.slice.call( arguments, 1 ) )

doT.autoloadDOM = ( opts ) ->
  ( name ) ->
    src = document.getElementById name
    if !src || !src.type || 'text/x-dot-tmpl' != src.type
      false
    else
      src.innerHTML

doT.autoloadFS = ( opts ) ->
  ( name ) ->
    try
      opts.fs.readFileSync "#{opts.root}/#{name.replace( '.', '/' )}.tmpl"
    catch e
      false

doT.autoloadFail = () -> false

doT.autoload = doT.autoloadDOM();

