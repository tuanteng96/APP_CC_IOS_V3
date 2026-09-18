<%@ page language="C#" autoeventwireup="true" inherits="cboCMS.Web.App.index" %>

<%=cboCMS.Web.WebControl.ReadFromTxt("AppCore/cached-webpgr.js","")%>

//<script>
    ;
    var Hotline =
        `<%=(new cboCMS.Core.Business.ConfigBLL().GetByName("chung.sdt") ?? new cboCMS.Core.Entities.ConfigEnt()).ValueText%>`;
    var WebConfig = {
        'NHAN_VIEN_DICH_VU_HOAN_THANH': '<%=cboCMS.Web.WebControl.AppSettings("NHAN_VIEN_DICH_VU_HOAN_THANH")%>',
        'DAT_HANG_KHO_AM': '<%=cboCMS.Web.WebControl.AppSettings("DAT_HANG_KHO_AM")%>'
    }
    window.Firebase =
        `<%=(new cboCMS.Core.Business.ConfigBLL().GetByName("App.webnoti") ?? new cboCMS.Core.Entities.ConfigEnt()).ValueText%>`;
    window.Firebase_Prefix = '<%=cboCMS.Core.Business.NotificationBLL.Firebase_Prefix%>';
    window.VER = new Date().getTime(); // '<%=VER%>';//
    window.SERVER = '<%=cboCMS.Web.WebControl.Domain%>';
    window.Now = new Date('<%=DateTime.Now%>');
    
    window.VERISON = "1.0.156";

    var vStorage = localStorage.getItem("_v");

    if(vStorage !== window.VERISON) {
        localStorage.setItem("_v", window.VERISON)
        document.querySelector("link[href*='index.css']").href = `${window.SERVER}/AppCoreV2/assets/css/index.css?v=${window.VERISON}`;
    }
    if(Number(window.PlatformVersion) > 2) {
        if(window.PlatformVersion === "8") {
            loadScript({
                url: `${SERVER}/AppCoreV2/assets/js/index.js`,
                name: "index.js",
                version: window.VERISON + window.VER,
                rel: "module"
            })
        }
        else {
            loadScript({
                url: `${SERVER}/AppCore25/assets/js/index.js`,
                name: "index.js",
                version: window.VERISON,
                rel: "module"
            })
        }
    }
    else {
        loadScript({
            url: `${SERVER}/AppCore/assets/js/index.js`,
            name: "index.js",
            version: window.VERISON,
            rel: "module"
        })
    }

//</script>