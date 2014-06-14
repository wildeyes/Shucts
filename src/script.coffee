$ = document.querySelectors

fastpick =
  numberingFromCSS : false
  runtimeOrExtension : if chrome.runtime and chrome.runtime.sendMessage then 'runtime' else 'extension'
  identifiers : '1234567890'
  shiftedIdentifiers : '!@#$%^&*()'
  openUrl : (url, mode) ->
    chrome[this.runtimeOrExtension].sendMessage url:url, mode:mode
  links: []
  openInline : (KBEvent, identifier) -> 
    this.openUrl this.links[this.identifiers.indexOf(identifier)], "inline"
  openNewTab : (KBEvent, identifier) -> this.openUrl this.links[this.shiftedIdentifiers.indexOf(identifier)], "newtab"
  openNewTabSwitch : (KBEvent, identifier) -> this.openUrl this.links[this.identifiers.indexOf(identifier.substring(2))], "newtabswitch"

# Helper Functions
utils =
  prepRegEx : (str) -> str.substr(1,str.length - 2)
  isRE  : (re) ->
    str = re.toString()
    str[0] == '/' && str[str.length - 1] == '/'
  isArr : (arr) -> Object.prototype.toString.call( arr ) is '[object Array]'
  bindkey : Mousetrap.bind

bind_navigation_keys = (metadata) ->
  inputsel = if metadata.inputsel? then metadata.inputsel else "input[type='text']"
  inputDOMElement = document.querySelector(inputsel);
  utils.bindkey 'e', gen_e_key_bind inputDOMElement, true
  utils.bindkey 'E', gen_e_key_bind inputDOMElement, false

gen_e_key_bind = (inputDOMElement, type) ->
  (e) ->
    e.preventDefault()
    inputDOMElement.focus()
    if type
      tmpval = inputDOMElement.value
      inputDOMElement.value = ''
      inputDOMElement.value = tmpval
    else
      inputDOMElement.select()
    # This is a very weird solution, but who gives a flying whale.. it works!

gen_is_this_page = (url) ->
  (page) ->
    isthis   = false
    page_selector  = page.domain

    # Check for array first! (utils.isRE converts arrays to string, so it may be passed arrays)
    if      utils.isArr page_selector
      another_is_this_page = gen_is_this_page url
      for pageurl in page_selector
        pageurl_encoded = domain:pageurl # TODO: Clean this hack
        isthis = isthis or another_is_this_page pageurl_encoded
        break if isthis
    else if utils.isRE page_selector
      isthis = url.match page_selector
    else if typeof page_selector is 'string'
      if page_selector is 'default'
        isthis = $(page.anchorsel).length isnt 0
      else
        isthis = url.indexOf(page_selector) isnt -1

    if isthis and page.exclude? and url.match page.exclude # Supports only regex excluding
      isthis = false

    return isthis

getPageMetadata = ->
  url = location.href
  page = null

  is_this_page = gen_is_this_page url

  for maybethis in database
    if is_this_page maybethis
      page = maybethis
      break;

  if page?
    if page.pages?
      for page in page.pages
        if is_this_page page
          return page
    else return page
  null

getElementsByMetadata = (metadata) ->
  asel = metadata.anchorsel
  # There's no db entry containing an iframe yet
  # if typeof asel is 'object'
  #   complexsel = asel
  #   for own key, val of complexsel
  #     if key is 'iframe'
  #       anchorElements = $('iframe').contents().find(val)
  # else if typeof asel is 'string'
  anchorElements = $ asel

  if metadata.hasOwnProperty "textsel"
    textElements = $ metadata.textsel
  else
    textElements = anchorElements

  {text:textElements,anchor:anchorElements}


metadata = do getPageMetadata

# if fastpick.numberingFromCSS
#   textsel = if metadata.textsel? then metadata.textsel else metadata.anchorsel
#   ((css) ->
#     # createStyleTag from CSS
#     head = document.head || document.getElementsByTagName("head")[0]
#     style = document.createElement("style")
#     style.type = "text/css"
#     if style.styleSheet
#       style.styleSheet.cssText = css
#     else 
#       style.appendChild(document.createTextNode(css))
#     head.appendChild(style))("

# #{textsel}:nth-child(n+9)::before {
#   counter-reset: level1 -1;
#   counter-increment: level1;
#   content: counter(level1) \". \";
# }
# #{textsel}::before {
# content: counter(level1) \". \";
# counter-increment: level1;}

#     ")


for i in [0...fastpick.identifiers.length]
  char = fastpick.identifiers[i]
  type = if char is '0' then 'keydown' else 'keypress' # zero char works only with keydown - probably chrome quirks

  utils.bindkey char, fastpick.openInline.bind(fastpick), type
  utils.bindkey fastpick.shiftedIdentifiers[i], fastpick.openNewTab.bind(fastpick), type
  utils.bindkey "= #{char}", fastpick.openNewTabSwitch.bind(fastpick), type

if metadata isnt null
  document.addEventListener "DOMContentLoaded", ->
    try 
      bind_navigation_keys metadata

      # TODO: will using a combination of array.map and zip will be of equal speed to this?
      identifierIndex = -1
      getNextIdentifier = -> 
        identifierIndex = identifierIndex + 1
        fastpick.identifiers[identifierIndex]
      
      elements = getElementsByMetadata(metadata)

      # Populate array with links that will later be called
      # by the mousetrap keybindings (that were binded early on)
      fastpick.links = elements.anchor.map -> @href

      # if not fastpick.numberingFromCSS
      elements.text.each (index, value) -> return unless index < fastpick.identifiers.length
        $ele = $( this )
        text = $ele.text()
        char = do getNextIdentifier
        $ele.text("#{char}. #{text}")

    catch e
      console.error "FastPick: Hey! I just erred! this is awkward. Could you please report this issue with the following information to https://github.com/wildeyes/fastpick/issues ?", e.stack