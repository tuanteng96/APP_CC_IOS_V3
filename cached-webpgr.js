function _cacheScript({
    name,
    version,
    url,
    rel
}) {
    var xmlhttp = new XMLHttpRequest(); // code for IE7+, Firefox, Chrome, Opera, Safari
    xmlhttp.onreadystatechange = function () {
        if (xmlhttp.readyState == 4) {
            if (xmlhttp.status == 200) {
                localStorage.setItem(name, JSON.stringify({
                    content: xmlhttp.responseText,
                    version: version,
                    rel
                }));
            } else {
                console.warn('error loading ' + url);
            }
        }
    }
    xmlhttp.open("GET", url, true);
    xmlhttp.send();
}

function _loadScript({
    url,
    name,
    version,
    callback,
    rel
}) {
    let isModulepreload = (rel == "modulepreload");
    let js = isModulepreload ? document.createElement("link") : document.createElement("script");
    if (isModulepreload) {
        js.rel = rel;
        js.href = url
        js.onload = () => {
            _cacheScript({
                name,
                version,
                url,
                rel
            });
        };
        js.onerror = (error) => console.log(error);

    } else {
        if (js.readyState) { //IE
            js.onreadystatechange = function () {
                if (js.readyState == "loaded" || js.readyState == "complete") {
                    js.onreadystatechange = null;
                    _cacheScript({
                        name,
                        version,
                        url,
                        rel
                    });
                    callback && callback();
                }
            };
        } else { //Others
            js.onload = function () {
                _cacheScript({
                    name,
                    version,
                    url,
                    rel
                });
                callback && callback();
            };
        }
        js.setAttribute("src", url);
        js.setAttribute("type", rel);
    }

    document.getElementsByTagName("head")[0].appendChild(js)
}

function _injectScript({
    jsStorage,
    url,
    name,
    version,
    callback,
    rel
}) {
    var jsStorageParse = JSON.parse(jsStorage);
    // cached version is not the request version, clear the cache, this will trigger a reload next time
    if (jsStorageParse.version != version) {
        localStorage.removeItem(name);
        _loadScript({
            url,
            name,
            version,
            callback,
            rel
        });
        return;
    }

    let js = document.createElement("script");
    js.type = jsStorageParse.rel

    var scriptContent = document.createTextNode(jsStorageParse.content);
    js.appendChild(scriptContent);
    document.getElementsByTagName("head")[0].appendChild(js);
    if (callback) callback();
}

function loadScript({
    name,
    version,
    url,
    callback,
    rel
}) {
    var jsStorage = localStorage.getItem(name);
    if (jsStorage == null) {
        _loadScript({
            url: `${url}?version=${version}`,
            name,
            version,
            callback,
            rel
        });
    } else {
        _injectScript({
            jsStorage,
            url: `${url}?version=${version}`,
            name,
            version,
            callback,
            rel
        });
    }
}

function loadScript2(src, callback)
{
  var s,
      r,
      t;
  r = false;
  s = document.createElement('script');
  s.type = 'text/javascript';
  s.src = src;
  s.onload = s.onreadystatechange = function() {
    //console.log( this.readyState ); //uncomment this line to see which ready states are called.
    if ( !r && (!this.readyState || this.readyState == 'complete') )
    {
      r = true;
      callback && callback();
    }
  };
  t = document.getElementsByTagName('script')[0];
  t.parentNode.insertBefore(s, t);
}


function LogJS(value) {
    var $log = document.createElement('div');
    $log.style.position = 'fixed';
    $log.style.left = '0';
    $log.style.top = '0';
    $log.style.right = '0';
    $log.style.color = '#fff';
    $log.style.background = '#000';
    $log.style.zIndex = 9999999;
    $log.innerHTML = value;
    document.body.appendChild($log);
}