/*jslint regexp: true, browser: true */

/* Don't use // style comments, or you'll break the stupid minifier  */
/* Hack to support nyroModal with jQuery 1.8, which removed $.curCss.
 * Upgrading to nyroModal V2 is another project - it has a different API.
 * Sigh.
 */
if (!$.curCSS) {
    $.curCSS = $.css;
}

/* EXPERT MODE */

var expertsMode = '';

function toggleExpertsMode(inMode) {
    "use strict";
    if (inMode !== undefined) {
        /* convert value to a css value */
        expertsMode = (inMode === 1 ? '' : 'none');
    } else {
        /* toggle */
        expertsMode = (expertsMode === 'none' ? '' : 'none');
    }

    var antimode = (expertsMode === 'none' ? '' : 'none');


    /* toggle table rows */
    $('tr.configureExpert').each(function () {
        $(this).css("display", expertsMode);
    });
    $('tr.configureNotExpert').each(function () {
        $(this).css("display", antimode);
    });
    /* toggle links */
    $('a.configureExpert').each(function () {
        $(this).css("display", expertsMode);
    });
    $('a.configureNotExpert').each(function () {
        $(this).css("display", antimode);
    });
}

/* ----------------------------- MENU ----------------------------- */

var tabLinks = {};

var menuState = {};
menuState.main = undefined;
menuState.defaultSub = {};
menuState.allOpened = -1;

function setMain(inId) {
    "use strict";
    menuState.main = inId;
}

function getMain() {
    "use strict";
    return menuState.main;
}

function setSub(inMainId, inSubId) {
    "use strict";
    menuState[inMainId] = inSubId;
}

function getSub(inMainId) {
    "use strict";
    return menuState[inMainId];
}

function setDefaultSub(inMainId, inSubId) {
    "use strict";
    if (menuState.defaultSub[inMainId]) {
        return;
    }
    menuState.defaultSub[inMainId] = inSubId;
}

function getDefaultSub(inMainId) {
    "use strict";
    return menuState.defaultSub[inMainId];
}

/**
   Returns an object with properties:
   main: main section id
   sub: sub section id (if any)
*/
function getSectionParts(inAnchor) {
    "use strict";
    var anchorPattern = new RegExp(/^#*(.*?)(\$(.*?))*$/),
        matches = inAnchor.match(anchorPattern),
        main = '',
        sub = '';
    if (matches && matches[1]) {
        main = matches[1];
        if (matches[3]) {
            main = matches[3];
            sub = matches[1] + '$' + main;
        }
    }
    return {
        main: main,
        sub: sub
    };
}

function showSection(inAnchor) {
    "use strict";
    var sectionParts = getSectionParts(inAnchor),
        mainId = sectionParts.main,
        subId = sectionParts.sub || getSub(mainId) || getDefaultSub(mainId),
        oldMainId = getMain(),
        currentMainElement,
        newMainElement,
        oldSubId,
        oldsub,
        currentSubElement,
        sub,
        newSubElement;

    if (oldMainId !== mainId) {
        /* hide current main section */
        currentMainElement = $("#" + oldMainId + "Body");
        currentMainElement.removeClass("configureShowSection");

        /* show new main section */
        newMainElement = $("#" + mainId + "Body");
        newMainElement.addClass("configureShowSection");

        /* set main menu highlight */
        if (tabLinks[oldMainId]) {
            $(tabLinks[oldMainId]).removeClass("configureMenuSelected");
        }
        if (tabLinks[mainId]) {
            $(tabLinks[mainId]).addClass("configureMenuSelected");
        }
    }

    /* hide current sub section */
    oldSubId = getSub(oldMainId);
    if (oldSubId) {
        oldsub = oldSubId;
        oldsub = oldsub.replace(/\$/g, "\\$");
        oldsub = oldsub.replace(/#/g, "\\#");
        currentSubElement = $("#" + oldsub + "Body");
        currentSubElement.removeClass('configureShowSection');
    }

    /* show new sub section */
    if (subId) {
        sub = subId;
        sub = sub.replace(/\$/g, "\\$");
        sub = sub.replace(/#/g, "\\#");
        newSubElement = $("#" + sub + "Body");
        newSubElement.addClass('configureShowSection');
    }

    /* set sub menu highlight */
    if (tabLinks[oldSubId]) {
        $(tabLinks[oldSubId]).removeClass("configureMenuSelected");
    }
    if (subId && tabLinks[subId]) {
        $(tabLinks[subId]).addClass("configureMenuSelected");
    }

    setMain(mainId);
    setSub(mainId, subId);

    if (menuState.allOpened === 1) {
        /* we want to use anchors to jump down */
        return true;
    }
    return false;
}

/*
  sub states are stored like this:
  var sub = 'Language';
  menuState[menuState.main].sub = sub;
*/
function initSection() {
    "use strict";
    if (document.location.hash && document.location.hash !== '#') {
        showSection(document.location.hash);
    } else {
        if ($("#WelcomeBody").length) {
            showSection('Welcome');
        } else {
            showSection('Introduction');
        }
    }
}


/**
   Support for the Expand/Close All button
   
   This is the preferred way to toggle elements. Should be done for Expert settings and Info blocks as well.
   
*/
function toggleSections() {
    "use strict";
    var body = $("body"),
        newMain;
    if (menuState.allOpened === -1) {
        /* open all sections */
        body.removeClass('configureShowOneSection');
    } else {
        /* hide all sections */
        body.addClass('configureShowOneSection');
        /* open current section */
        newMain = menuState.main;
        menuState.main = '';
        showSection(newMain);
    }

    menuState.allOpened = -menuState.allOpened;
}

/* TOOLTIPS */

function getTip(idx) {
    "use strict";
    var div = $("#tt" + idx);
    if (div.length) {
        return div.innerHTML;
    }
    return "Reset to the default value, which is:<br />";
}

/* DEFAULT LINKS */

/**
   Initializes the 2 states of "reset to default" links.
   State 1: restore to default
   State 2: undo restore
*/
function initDefaultLink(inLink) {
    "use strict";
    /* extract type */
    var type = inLink.className.split(" ")[0],
        label;

    inLink.type = type;

    /* retrieve value from title tag */
    if (inLink.type === 'OCTAL') {
        inLink.defaultValue = parseInt(unescape(inLink.title), 8).toString(8);
    } else {
        inLink.defaultValue = unescape(inLink.title);
    }

    /* set link label states */
    inLink.setDefaultLinkText = 'use default';
    inLink.undoDefaultLinkText = 'use stored value';

    /* set defaults */
    inLink.title = '';

    label = $('.configureDefaultValueLinkLabel', inLink)[0];
    if (label) {
        label.innerHTML = inLink.setDefaultLinkText;
    }
}

/**
   Checks if a value can be considered true.
*/
function isTrue(v) {
    "use strict";
    if (v === 1 || v === '1' || v === 'on' || v === 'true') {
        return 1;
    }
    return 0;
}

/**
   Translates a value to a readable string that makes sense in a form.
   For instance, 'false' gets translated to 'off' with checkboxes.
   
   Possible types:
   URL
   PATH
   URLPATH
   STRING
   BOOLEAN
   NUMBER
   SELECTCLASS
   SELECT
   REGEX
   OCTAL
   COMMAND
   PASSWORD
   PERL (?)
*/
function createHumanReadableValueString(inType, inValue) {
    "use strict";
    if (inType === 'NUMBER') {
        /* do not convert numbers */
        return inValue;
    }
    if (inType === 'BOOLEAN') {
        if (isTrue(inValue)) {
            return 'on';
        }
        return 'off';
    }
    if (!inValue.length) {
        return '""';
    }
    /* all other cases */
    return inValue;
}

function showDefaultLinkToolTip(inLink) {
    "use strict";
    var template = $("#configureToolTipTemplate").html(),
        contents;

    template = template.replace(/VALUE/g, createHumanReadableValueString(inLink.type, inLink.defaultValue));
    template = template.replace(/TYPE/g, inLink.type);

    contents = $('.configureDefaultValueLinkValue', inLink)[0];
    $(contents).html(template);
}

/**
   Called from "reset to default" link.
   Values are set in UIs/Value.pm
*/
function resetToDefaultValue(inLink, inFormType, inName, inValue) {
    "use strict";
    var name = unescape(inName),
        elem = document.forms.update[name],
        value,
        oldValue,
        type,
        label,
        index,
        i;

    if (!elem) {
        return false;
    }

    value = unescape(inValue);
    if (inLink.oldValue) {
        value = inLink.oldValue;
    }

    type = elem.type;

    if (type === 'checkbox') {
        oldValue = elem.checked;
        elem.checked = value;
    } else if (type === 'select-one') {
        /* find selected element */
        for (i = 0; i < elem.options.length; i = i + 1) {
            if (elem.options[i].value === value) {
                index = i;
                break;
            }
        }
        oldValue = elem.options[elem.selectedIndex].value;
        elem.selectedIndex = index;
    } else if (type === 'radio') {
        oldValue = elem.checked;
        elem.checked = value;
    } else {
        /* including type='text'  */
        if (inLink.type === 'OCTAL') {
            oldValue = parseInt(elem.value, 8).toString(8);
            elem.value = parseInt(value, 8).toString(8);
        } else {
            oldValue = elem.value;
            elem.value = value;
        }
    }

    label = $('.configureDefaultValueLinkLabel', inLink)[0];
    if (!inLink.oldValue) {
        /* we have just set the default value */
        /* prepare undo link */
        label.innerHTML = inLink.undoDefaultLinkText;
        inLink.oldValue = oldValue;
    } else {
        /* we have just set the old value */
        label.innerHTML = inLink.setDefaultLinkText;
        inLink.oldValue = null;
    }

    return false;
}

/* INFO TEXTS */

var infoMode = '';

function toggleInfoMode() {
    "use strict";
    var antimode = infoMode;
    infoMode = (antimode === 'none' ? '' : 'none');
    $('.configureInfoText').each(function () {
        if (infoMode === 'none') {
            $(this).addClass('foswikiMakeHidden');
        } else {
            $(this).removeClass('foswikiMakeHidden');
        }
    });
    $('.configureNotInfoText').each(function () {
        if (antimode === 'none') {
            $(this).addClass('foswikiMakeHidden');
        } else {
            $(this).removeClass('foswikiMakeHidden');
        }
    });
}


/**
   Opens/closes all info blocks.
*/
function toggleInfo(inId) {
    "use strict";
    var twistyElement = $("#info_" + inId);
    if (twistyElement) {
        if (twistyElement.hasClass("foswikiMakeHidden")) {
            twistyElement.removeClass("foswikiMakeHidden");
        } else {
            twistyElement.addClass("foswikiMakeHidden");
        }
    }
    return false;
}

/* SELECTORS */

/* Quote a name per CSS quoting rules so that it can be used as a JQuery selector */

function quoteName(name) {
    "use strict";
    var instr = name.split(""),
        out = '',
        i,
        c;
    for (i = 0; i < name.length; i = i + 1) {
        c = instr[i];
        if ("!\"#$%&'()*+,./:;<=>?@[\\]^`{|} ~".indexOf(c) >= 0) {
            out = out + '\\' + (c === ':' ? '\\3a' : c);
        } else {
            out = out + c;
        }
    }
    return out;
}

var enableWhenSomethingChangedElements = [];
var showWhenNothingChangedElements = [];

/* Value changes. Event when a value is edited; enables the save changes
 * button.  Also clicks feedback request button(s) for auto-feedback items.
 * The ^= is because 'feedreq' is followed by a button number.
 */
function valueChanged(el) {
    "use strict";
    switch (el.type.toLowerCase()) {
    case "select-one":
    case "select-multiple":
    case "textarea":
    case "text":
    case "password":
    case "radio":
    case "checkbox":
        $('[id^="' + quoteName(el.name) + 'feedreq"]').filter('[value="~"]').click();
        break;
    default:
        break;
    }
    $(el).addClass('foswikiValueChanged');

    $(showWhenNothingChangedElements).each(function () {
        $(this).addClass('foswikiHidden');
    });

    $(enableWhenSomethingChangedElements).each(function () {
        var controlTypes = ['Submit', 'Button', 'InputField'],
            jlen = controlTypes.length,
            j,
            ct;
        $(this).removeClass('foswikiHidden');
        for (j = 0; j < jlen; j = j + 1) {
            ct = 'foswiki' + controlTypes[j];
            if ($(this).hasClass(ct + 'Disabled')) {
                $(this).removeClass(ct + 'Disabled');
                $(this).addClass(ct);
            }
        }
        $(this).disabled = false;
    });
}

function valueOf($el) {
    "use strict";
    if ($el.attr("type") === "checkbox") {
        return $el.is(":checked");
    }
    return $el.val();
}

function newHideContent(elts, settings, callback) {
    "use strict";
    elts.contentWrapper.hide();
    callback();
}

function loadImage(el) {
    "use strict";
    var url,
        img;
    if (!el.title || el.title === '') {
        return;
    }
    url = el.title;
    el.title = 'Click to enlarge';

    img = new Image();
    $(img).load(function () {
        var w = this.width,
            h = this.height,
            MAX_H = 64,
            MAX_W = 150;
        /* set the image hidden by default */
        $(img).hide();
        /* Scale to max 64 height, max 150 width */
        if (w * MAX_H / MAX_W > h) {
            this.height = Math.round(h * MAX_W / w);
            this.width = MAX_W;
        } else {
            this.width = Math.round(w * MAX_H / h);
            this.height = MAX_H;
        }

        $(el).append(this);
        $(this).wrap("<a href='" + url + "' class='nyroModal'></a>");
        $('.nyroModal').nyroModal({
            hideContent: newHideContent
        });
        $(this).fadeIn();
    });
    $(img).attr('src', url);
}

var allImagesLoaded = false;

function imgOnDemand() {
    "use strict";
    if (!allImagesLoaded) {
        var p = $(window).height() + $(window).scrollTop();
        $('.loadImage').each(function () {
            if ($(this).offset().top < p + 50) {
                loadImage(this);
                $(this).removeClass('loadImage');
            }
        });
        allImagesLoaded = (p >= $(document).height());
    }
}

/**
   Javascript query string parsing.
   Author: djohnson@ibsys.com {{djohnson}} - you may use this file as you wish but please keep this header with it thanks
   @use 
   Pass location.search to the constructor:
   <code>var myPageQuery = new PageQuery(location.search)</code>
   Retrieve values
   <code>var myValue = myPageQuery.getValue("param1")</code>
*/
var PageQuery;
PageQuery = function (q) {
    "use strict";
    var i;
    if (q.length > 1) {
        this.q = q.substring(1, q.length);
    } else {
        this.q = null;
    }
    this.keyValuePairs = [];
    if (q) {
        for (i = 0; i < this.q.split(/[&;]/).length; i = i + 1) {
            this.keyValuePairs[i] = this.q.split(/[&;]/)[i];
        }
    }
};
PageQuery.prototype.getKeyValuePairs = function () {
    "use strict";
    return this.keyValuePairs;
};
/**
   @return The query string value; if not found returns -1.
*/
PageQuery.prototype.getValue = function (s) {
    "use strict";
    var j;
    for (j = 0; j < this.keyValuePairs.length; j = j + 1) {
        if (this.keyValuePairs[j].split("=")[0] === s) {
            return this.keyValuePairs[j].split("=")[1];
        }
    }
    return -1;
};
PageQuery.prototype.getParameters = function () {
    "use strict";
    var a = [],
        j;
    for (j = 0; j < this.keyValuePairs.length; j = j + 1) {
        a[j] = this.keyValuePairs[j].split("=")[0];
    }
    return a;
};
PageQuery.prototype.getLength = function () {
    "use strict";
    return this.keyValuePairs.length;
};

function getUrlParam(inName) {
    "use strict";
    var myPageQuery = new PageQuery(location.search),
        param = myPageQuery.getValue(inName);
    return (param === -1 ? undefined : param);
}

/**
 * jquery init 
 */
$(document).ready(function () {
    "use strict";
    $(".enableWhenSomethingChanged").each(function () {
        enableWhenSomethingChangedElements.push(this);
        if (this.tagName.toLowerCase() === 'input') {
            /* disable the Save Changes button until a change has been made */
            /* we won't use this until an AJAX call has been implemented to make
	       this fault proof
	       $(this).attr('disabled', 'disabled');
	       $(this).addClass('foswikiSubmitDisabled');
	       $(this).removeClass('foswikiSubmit');
	    */
            var placeholder = 1;
        } else {
            $(this).addClass('foswikiHidden');
        }
    });
    $(".showWhenNothingChanged").each(function () {
        showWhenNothingChangedElements.push(this);
    });
    $(".tabli a").each(function () {
        var sectionParts = getSectionParts(this.hash);
        this.sectionId = sectionParts.main;
        if (sectionParts.sub) {
            this.sectionId = sectionParts.sub;
            setDefaultSub(sectionParts.main, sectionParts.sub);
        }
        tabLinks[this.sectionId] = $(this).parent().get(0);
    });
    $(".tabli a").click(function () {
        return showSection(this.sectionId);
    });
    $("a.configureExpert").click(function () {
        toggleExpertsMode();
        return false;
    });
    $("a.configureNotExpert").click(function () {
        toggleExpertsMode();
        return false;
    });
    $("a.configureInfoText").click(function () {
        toggleInfoMode();
        return false;
    });
    $("a.configureNotInfoText").click(function () {
        toggleInfoMode();
        return false;
    });
    $("a.configureDefaultValueLink").each(function () {
        initDefaultLink(this);
    });
    $("a.configureDefaultValueLink", $("div.configureRootSection")).mouseover(function () {
        showDefaultLinkToolTip(this);
    });
    $(".configureToggleSections a").click(function () {
        toggleSections();
    });
    $("input.foswikiFocus").each(function () {
        this.focus();
    });
    $(".configureRootSection table.configureSectionValues div.configureError").each(function () {
        var row = $(this).closest('tr').get(0);
        if (row) {
            $(row).removeClass('configureExpert');
        }
    });
    $(".configureRootSection table.configureSectionValues div.configureWarning").each(function () {
        var row = $(this).closest('tr').get(0);
        if (row) {
            $(row).removeClass('configureExpert');
        }
    });
    $("#closeMessages").click(function () {
        $("#messages").hide();
        return false;
    });
    var add_dependency = function ($el, name, cb) {
        var test = $el.attr("data-" + name);
        //$el.attr("data-" + name, "");
        // Add change handlers to all vars, identified by {\w+}{... syntax
        test = test.replace(/((?:\{\w+\})+)/g, function (str, p1, offset) {
            var selector = '[name="' + p1 + '"]';
            $(selector).change(function () {
                $el.triggerHandler(name + '_change');
            });
            return "valueOf($('" + selector + "'))";
        });
        // Bind a change event handler to this dependent, which will be fired if any of
        // the things it depends on changes.
        $el.bind(name + '_change', function (e) {
            cb($el, eval('(' + test + ')') ? true : false);
        });
        // Set up initial conditions by triggering the handler
        $el.triggerHandler(name + '_change');
    };

    $("[data-displayif]").each(function () {
        add_dependency($(this), "displayif", function ($el, tf) {
            $el.toggle(tf);
        });
    });
    $("[data-enableif]").each(function () {
        add_dependency($(this), "enableif", function ($el, tf) {
            if (tf) {
                $el.find("input,textarea").removeAttr('disabled').removeClass('foswikiSubmitDisabled');
            } else {
                $el.find("input,textarea").attr('disabled', 'disabled').addClass('foswikiSubmitDisabled');
            }
        });
    });
    toggleExpertsMode(getUrlParam('expert'));
    toggleInfoMode();
    initSection();
    $(window).scroll(function () {
        imgOnDemand();
    });
    imgOnDemand();
});

function setSubmitAction(button) {
    "use strict";
    $(button.form).find('input[type="hidden"][name="action"]').val(button.value);
    return true;
}

/* ---------------------------- FEEDBACK -------------------------- */

function doFeedback(key, pathinfo) {

    /* Make (and post) an http(s) request for feedback.
     *
     * First, some private infrastructure:
     */

    /* multipart/form-data item and body construction */

    var boundary = '------Foswiki-formboundary' + (new Date()).getTime() + Math.floor(Math.random() * 1073741826).toString(),
        dashdash = '--',
        crlf = '\015\012',
        requestData = "",
        quoteKeyId = quoteName(key.id), /* Selector-encoded id of button that was clicked */
        KeyIdSelector = '#' + quoteKeyId,
        posturl = document.location.pathname, /* Where to post form */
        working,
        stsWindowId;

    /* Add a named item from a form to the POST data */

    function postFormItem(name, value) {
        requestData = requestData + (dashdash + boundary + crlf) + 'Content-Disposition: form-data; name="' + name + '"' + crlf + crlf + value + crlf;
        return;
    }

    /* Effectively alert(), but supporting HTML content.  */
    function errorMessage(m) {
        if (m.length <= 0) {
            m = "Unknown error encountered";
        }
        /* nyroModal has wierd styles on <pre> that shrink to unreadability, 
         * switch to <code> as <pre> s used by CGI::Carp.
         */
        m = m.replace(/<(\/)?pre>/gi, "<$1code>").replace(/\n/g, '<br />');

        var contents = '<div id="configureFeedbackErrorWindow" class="configureFeedbackError" style="display:none">' + m + '</div>';
        /* If we already have the necessary DOM, re-use it.  Otherwise, we'll put it after the
         * last button pressed.  It's just a place we know how to find; the DOM is not visible.
         * It would be good to remove the DOM on close, but the various versions and states of
         * nyroModal make that more trouble than it's worth.  The wrapping div is for CSS.
         *
         * An invisible link is made modal.  That link's hashtag points tothe *id* of an invisible
         * div, which holds the content.  The *div* isn't modal.  The link is clicked once the 
         * div is created (or replaced), and nyroModal handles things from there.
         * Somewhat arcane, but that's the way nyroModal works.
         */

        if ($('#configureFeedbackErrorWindow').size() === 0) { /* Don't have error window */
            $('#' + quoteKeyId).after('<a href="#configureFeedbackErrorWindow" class="configureFeedbackError" id="configureFeedbackErrorLink"></a>' + contents);
            $('#configureFeedbackErrorLink').nyroModal().click();
        } else { /* Re-use the window and link */
            $('#configureFeedbackErrorWindow').replaceWith(contents);
            $('#configureFeedbackErrorLink').click();
        }
    }

    /* Error window - could go to status bar, but this seems to be effective. 
     * Extract content for a div, stripping page overhead.
     */

    function errorMessageFromHTML(m) {
        errorMessage(m.replace(/\r?\n/mgi, '<crlf>').replace(/^.*<body>/mgi, '').replace(/<\/body>.*$/mgi, '').replace(/<\/?html>/mgi, '').replace(/<crlf>/mg, "\n"));
    }

    /* Request handling:
     */

    if (posturl === undefined || !posturl.length) {
        posturl = $(KeyIdSelector).closest('form').attr('action');
    }

    /* Used for pathinfo testing */

    if (pathinfo !== undefined && pathinfo.length) {
        posturl = posturl + pathinfo;
    }

    /* Scan all the input controls in the form containing the button,
     * Include successful controls.  Skip disabled and nameless controls.
     */

    $(KeyIdSelector).closest('form').find(":input").each(function (index) {
        var opts,
            i,
            ilen,
            ctlName,
            txt;
        if (this.disabled) {
            return true;
        }
        ctlName = this.name;
        if (!this.name.length) {
            return true;
        }
        switch (this.type.toLowerCase()) {
        /* Ignore these */
        case "file":
        case "submit":
            /* Submit buttons weren't clicked, so don't report them */
        case "reset":
            /* Reset controls are never submitted, local action only */
            return true;

        case "select-one":
        case "select-multiple":
            /* Select sends the value of each selected option */
            opts = this.options;
            ilen = opts.length;
            for (i = 0; i < ilen; i = i + 1) {
                if (opts[i].selected && !opts[i].disabled) {
                    postFormItem(ctlName, opts[i].value);
                }
            }
            return true;

        case "textarea":
            /* Deal with end of line variations - must normalize to <cr><lf> */
            txt = this.value.replace(/([^\r])\n/mg, "$1\r\n").replace(/\r([^\n])/mg, "\r\n$1").replace(/\r\n/, crlf);
            postFormItem(ctlName, txt);
            return true;

        case "hidden":
        case "text":
        case "password":
            postFormItem(ctlName, this.value);
            return true;

        case "radio":
        case "checkbox":
            if (this.checked) {
                postFormItem(ctlName, this.value);
            }
            return true;

        default:
            break;
        }
        /* Ignore all other controls */
        return true;
    });

    /* Mark as feedback request */

    postFormItem('FeedbackRequest', key.id);
    postFormItem('FeedbackButtonValue', key.value);
    postFormItem('action', 'feedbackUI');

    /* End of post boundary */

    requestData = requestData + dashdash + boundary + dashdash + crlf;

    /* Update message area with busy status. I18n note:  hidden disabled field in pagebegin.tmpl with desired
     * text for internationalization.  E.g. <input type="hidden" disabled="disabled"
     * id="configureFeedbackWorkingText" value="Nous travaillons sur votre demande...">
     */

    working = $('#configureFeedbackWorkingText').filter(':hidden').filter(':disabled');
    if (working.size() === 1) {
        working = working.get(0).value;
    } else {
        working = 'Working...';
    }
    stsWindowId = key.id.replace(/feedreq\d+$/, 'status');
    $('#' + quoteName(stsWindowId)).replaceWith("<div id=\"" + stsWindowId + "\" class=\"configureFeedbackPending\"><span class=\"configureFeedbackPendingMessage\">" + working + "</span></div>");

    /* Make the request
     * ** N.B. Definitely broken with jQuery 1.3 (unreliable selectors), 1.8.2 used.
     */

    $.ajax({
        url: posturl,
        cache: false,
        dataType: "text",
        type: "POST",
        global: false,
        contentType: "multipart/form-data; boundary=\"" + boundary + '"; charset=UTF-8',
        accepts: {
            text: "text/plain",
            text: "text/html"
        },
        headers: {
            'X-Foswiki-FeedbackRequest': 'V1.0'
        },
        processData: false,
        data: requestData,
        error: function (xhr, status, err) {
            if (!xhr.getAllResponseHeaders()) {
                /* User abort (no server response)
                 * There is no reliable status code to detect this, which
                 * happens when an AJAX request is cancelled by navigation.
                 */
                return true;
            }

            /* Clear "working" status */

            $('#' + quoteName(stsWindowId)).replaceWith("<div id=\"" + stsWindowId + "\" class=\"configureFeedback\"></div>");

            /* Perhaps this should go to the status bar? */

            errorMessage('<h1>' + xhr.status.toString() + " " + xhr.statusText + "</h1>" + xhr.responseText);
            return true;
        },
        /* Using complete ensures that jQuery provides xhr on success.
         */

        complete: function (xhr, status) {
            if (status !== 'success') {
                return true;
            }

            /* Make sure this is a feedback response, as some browsers
             * seem to sometimes return other data...
             */
            if (xhr.getResponseHeader('X-Foswiki-FeedbackResponse') !== 'V1.0') {
                return true;
            }

            var data = xhr.responseText,
                items,
                i,
                kpair,
                sloc,
                delims,
                d,
                newval,
                opts,
                v,
                ii;

            /* Clear "working" status in case of errors or updates that don't target
             * the original status div.  This also updates the class.
             */
            $('#' + quoteName(stsWindowId)).replaceWith("<div id=\"" + stsWindowId + "\" class=\"configureFeedback\"></div>");

            /* Decide what kind of response we got. */

            if (data.charAt(0) !== '{') { /* Probably an error page with OK status */
                if (data.charAt(0) !== "\177") { /* Ignore no data response */
                    if (data.length <= 0) {
                        data = "Empty response received from feedback request";
                    }
                    errorMessageFromHTML(data);
                }
                return true;
            }

            /* Distribute response for each key to its status div or value */
            /* Hex constants used rather than octal for JSLint issue. */

            items = data.split("\x01");
            for (i = 0; i < items.length; i = i + 1) {
                /* IE sometimes doesn't do capturing split, so simulate one. */
                kpair = [];
                delims = ["\x02", "\x03"];
                for (d = 0; d < delims.length; d = d + 1) {
                    sloc = items[i].indexOf(delims[d]);
                    if (sloc >= 0) {
                        kpair[0] = items[i].substr(0, sloc);
                        kpair[1] = delims[d];
                        kpair[2] = items[i].substr(sloc + 1);
                        break;
                    }
                }
                if (d >= delims.length) {
                    errorMessage("Invalid opcode in feedback response");
                    return true;
                }
                if (kpair[1] === "\x02") {
                    $("#" + quoteName(kpair[0]) + "status").html(kpair[2]);
                } else if (kpair[1] === "\x03") {
                    newval = kpair[2].split(/\x04/);
                    $('[name="' + quoteName(kpair[0]) + '"]').each(function (idx, ele) {
                        switch (this.type.toLowerCase()) {
                        /* Ignore these for now (why update labels?) */
                        case "button":
                        case "file":
                        case "submit":
                        case "reset":
                            return true;

                        case "select-one":
                            opts = this.options;
                            var selected = -1;

                            for (i = 0; i < opts.length; i = i + 1) {
                                if (opts[i].value === newval[0]) {
                                    opts[i].selected = true;
                                    this.selectedIndex = i;
                                    selected = i;
                                } else {
                                    opts[i].selected = false;
                                }
                            }
                            if (selected < 0) {
                                errorMessage("Invalid value \"" + newval[0] + "\" for " + kpair[0]);
                            }
                            return true;

                        case "select-multiple":
                            opts = this.options;

                            for (i = 0; i < opts.length; i = i + 1) {
                                opts[i].selected = false;
                            }
                            this.selectedIndex = -1;
                            for (v = 0; v < newval.length; v = v + 1) {
                                for (ii = 0; ii < opts.length; ii = ii + 1) {
                                    if (opts[ii].value === newval[v]) {
                                        opts[ii].selected = true;
                                        if (v === 0) {
                                            this.selectedIndex = ii;
                                        }
                                        break;
                                    }
                                }
                                if (i >= opts.length) {
                                    errorMessage("Invalid value \"" + newval[v] + "\" for " + kpair[0]);
                                }
                            }
                            return true;

                        case "textarea":
                        case "hidden":
                        case "text":
                        case "password":
                            this.value = newval.join("");
                            return true;

                        case "radio":
                        case "checkbox":
                            this.checked = isTrue(newval[0]);
                            return true;
                        default:
                            break;
                        }
                        /* Ignore all other controls */
                        return true;
                    });

                } else { /* This is not possible */
                    errorMessage("Invalid opcode2 in feedback response");
                }
            }
            return true;
        }
    });

    /* Consume the button click */

    return false;
}