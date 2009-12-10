/* Don't use // style comments, or you'll break the stupid minifier  */

/* EXPERT MODE */

var expertsMode = '';

function toggleExpertsMode() {
    var antimode = expertsMode;
    expertsMode = (antimode == 'none' ? '' : 'none');
    $('.configureExpert').each(function() {
    	$(this).css("display", expertsMode);
    });
    $('.configureNotExpert').each(function() {
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
	menuState.main = inId;
}
function getMain() {
	return menuState.main;
}
function setSub(inMainId, inSubId) {
	menuState[inMainId] = inSubId;
}
function getSub(inMainId) {
	return menuState[inMainId];
}
function setDefaultSub(inMainId, inSubId) {
	if (menuState.defaultSub[inMainId]) return;
	menuState.defaultSub[inMainId] = inSubId;
}
function getDefaultSub(inMainId) {
	return menuState.defaultSub[inMainId];
}

/*
sub states are stored like this:
var sub = 'Language';
menuState[menuState.main].sub = sub;
*/
function initSection() {

	if (document.location.hash && document.location.hash != '#') {
		showSection(document.location.hash);
	} else {
		if ( $("#WelcomeBody").length ) {
			showSection('Welcome');
		} else {
			showSection('Introduction');
		}
	}
}

/**
Returns an object with properties:
	main: main section id
	sub: sub section id (if any)
*/
var anchorPattern = new RegExp(/^#*(.*?)(\$(.*?))*$/);

function getSectionParts(inAnchor) {
	
    var matches = inAnchor.match(anchorPattern);
	var main = '';
    var sub = '';
    if (matches && matches[1]) {
        main = matches[1];
        if (matches[3]) {
        	main = matches[3];
        	sub = matches[1] + '$' + main;
        }
    }
    return {main:main, sub:sub};
}

function showSection(inAnchor) {

	var sectionParts = getSectionParts(inAnchor);
	var mainId = sectionParts.main;
	var subId = sectionParts.sub || getSub(mainId) || getDefaultSub(mainId);
	
	var oldMainId = getMain();
	
	if (oldMainId != mainId) {	
		/* hide current main section */
		var currentMainElement = $("#" + oldMainId + "Body");
		currentMainElement.removeClass("configureShowSection");
	
		/* show new main section */
		var newMainElement = $("#" + mainId + "Body");	
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
	var oldSubId = getSub(oldMainId);
	if (oldSubId) {
		var oldsub = oldSubId;
		oldsub = oldsub.replace(/\$/g, "\\$");
		oldsub = oldsub.replace(/#/g, "\\#");
		var currentSubElement = $("#" + oldsub + "Body");
		currentSubElement.removeClass('configureShowSection');
	}
	
	/* show new sub section */
	if (subId) {
		var sub = subId;
		sub = sub.replace(/\$/g, "\\$");
		sub = sub.replace(/#/g, "\\#");
		var newSubElement = $("#" + sub + "Body");	
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

	if (menuState.allOpened == 1) {
		/* we want to use anchors to jump down */
		return true;
	} else {
		return false;
	}
}

/**
Support for the Expand/Close All button

This is the preferred way to toggle elements. Should be done for Expert settings and Info blocks as well.

*/
function toggleSections() {

    var body = $("body");
    if (menuState.allOpened == -1) {
    	/* open all sections */
		body.removeClass('configureShowOneSection');
	} else {
		/* hide all sections */
		body.addClass('configureShowOneSection');
		/* open current section */
		var newMain = menuState.main;
		menuState.main = '';
		showSection(newMain);
	}
	
	menuState.allOpened = -menuState.allOpened;
}

/* TOOLTIPS */

function getTip(idx) {
    var div = $("#tt" + idx);
    if (div.length)
        return div.innerHTML;
    else
        return "Reset to the default value, which is:<br />";
}

/* DEFAULT LINKS */

/**
Initializes the 2 states of "reset to default" links.
State 1: restore to default
State 2: undo restore
*/
function initDefaultLink(inLink) {

	/* extract type */
	var type = inLink.className.split(" ")[0];
	inLink.type = type;
	
	/* retrieve value from title tag */
	inLink.defaultValue = decode(inLink.title);

	/* set link label states */
	inLink.setDefaultLinkText = 'use default';
	inLink.undoDefaultLinkText = 'undo';
	
	/* set defaults */
	inLink.title = '';
	/*
	inLink.title = formatLinkValueInTitle(
        inLink.type, inLink.setDefaultTitle, inLink.defaultValue);
    */
    var label = $('.configureDefaultValueLinkLabel', inLink)[0];
    if (label) {
		label.innerHTML = inLink.setDefaultLinkText;
	}
}

function showDefaultLinkToolTip(inLink) {

	var template = $("#configureToolTipTemplate").html();
	template = template.replace(/VALUE/g, createHumanReadableValueString(inLink.type, inLink.defaultValue));
	template = template.replace(/TYPE/g, inLink.type);

	var contents = $('.configureDefaultValueLinkValue', inLink)[0];
	$(contents).html(template);
}

/**
Prepend a string to a human readable value string.
*/
function formatLinkValueInTitle (inType, inString, inValue) {
	return (inString + createHumanReadableValueString(inType, inValue));
}

/**
Called from "reset to default" link.
Values are set in UIs/Value.pm
*/
function resetToDefaultValue (inLink, inFormType, inName, inValue) {

	var name = decode(inName);
	var elem = document.forms.update[name];
	if (!elem) return;
	
	var value = decode(inValue);
	if (inLink.oldValue != null) value = inLink.oldValue;

	var oldValue;
	var type = elem.type;

	if (type == 'checkbox') {
		oldValue = elem.checked;
		elem.checked = value;
	} else if (type == 'select-one') {
		/* find selected element */
		var index;
		for (var i=0; i<elem.options.length; ++i) {
			if (elem.options[i].value == value) {
				index = i;
				break;
			}
		}
		oldValue = elem.options[elem.selectedIndex].value;
		elem.selectedIndex = index;
	} else if (type == 'radio') {
		oldValue = elem.checked;
		elem.checked = value;
	} else {
		/* including type='text'  */
		oldValue = elem.value;
		elem.value = value;
	}
	
	var label = $('.configureDefaultValueLinkLabel', inLink)[0];
	if (inLink.oldValue == null) {
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
function createHumanReadableValueString (inType, inValue) {
	if (inType == 'NUMBER') {
		/* do not convert numbers */
		return inValue;
	}
	if (inType == 'BOOLEAN') {
		if (isTrue(inValue)) {
			return 'on';
		} else {
			return 'off';
		}
	}
	if (inValue.length == 0) {
		return '""';
	}
	/* all other cases */
	var value = inValue;
	value = value.replace(/\\&quot;/g, '');
	return value;
}

/**
Checks if a value can be considered true.
*/
function isTrue (v) {
	if (v == 1 || v == '1' || v == 'on' || v == 'true')
        return 1;
	return 0;
}

/**
Replaces encoded characters with the real characters.
*/
function decode(v) {
	var re = new RegExp(/#(\d\d)/g);
	return v.replace(re,
                     function (str, p1) {
                         return String.fromCharCode(parseInt(p1));
                     });
}

/* INFO TEXTS */

var infoMode = '';

function toggleInfoMode() {
    var antimode = infoMode;
    infoMode = (antimode == 'none' ? '' : 'none');
    $('.configureInfoText').each(function() {
    	if (infoMode == 'none') {
        	$(this).addClass('foswikiMakeHidden');
        } else {
        	$(this).removeClass('foswikiMakeHidden');
        }
    });
	$('.configureNotInfoText').each(function() {
        if (antimode == 'none') {
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
var enableWhenSomethingChangedElements = new Array();
var showWhenNothingChangedElements = new Array();

/* Value changes. Event when a value is edited; enables the save changes
 * button */
function valueChanged(el) {

    $(el).addClass('foswikiValueChanged');

	$(showWhenNothingChangedElements).each(function() {
		$(this).addClass('foswikiHidden');
	});
	
	$(enableWhenSomethingChangedElements).each(function() {
		var controlTypes = [ 'Submit', 'Button', 'InputField' ];
		$(this).removeClass('foswikiHidden');
		for (var j in controlTypes) {
			var ct = 'foswiki' + controlTypes[j];
			if ($(this).hasClass(ct + 'Disabled')) {
				$(this).removeClass(ct + 'Disabled');
				$(this).addClass(ct);
			}
		}
		$(this).disabled = false;
	});
}

(function($) {
    $.fn.extensionImage = function(){
        $("body").append("<div id='extensionImage' style='position: absolute; z-index: 100; display: none;'><img id='extensionImageImage' src='' /></div>");
        return this.each(
            function() {
                var url = $(this).attr("image");
                if (url == null)
                    return;
                $(this).hover(
                    function(e){
                        var tipX = e.pageX + 12;
                        var tipY = e.pageY + 12;
                        $("#extensionImageImage").attr("src", url);
                        if ($.browser.msie)
                            var tipWidth = $("#extensionImage")
                                .outerWidth(true);
                        else
                            var tipWidth = $("#extensionImage").width();
                        $("#extensionImage").width(tipWidth);
                        $("#extensionImage").css("left", tipX)
                            .css("top", tipY).fadeIn("fast");
                    },
                    function() {
                        $("#extensionImage").fadeOut("fast");
                    });
                $(this).mousemove(
                    function(e){
                        var tipX = e.pageX + 12;
                        var tipY = e.pageY + 12;
                        var tipWidth = $("#extensionImage")
                            .outerWidth(true);
                        var tipHeight = $("#extensionImage")
                            .outerHeight(true);
                        if (tipX + tipWidth > $(window).scrollLeft()
                            + $(window).width()) 
                            tipX = e.pageX - tipWidth;
                        if ($(window).height()+$(window).scrollTop()
                            < tipY + tipHeight)
                            tipY = e.pageY - tipHeight;
                        $("#extensionImage").css("left", tipX)
                            .css("top", tipY).fadeIn("fast");
                    });
            });
    }})(jQuery);

/**
 * jquery init 
 */
$(document).ready(function() {
	$(".enableWhenSomethingChanged").each(function() {
		enableWhenSomethingChangedElements.push(this);
		if (this.tagName.toLowerCase() == 'input') {
			/* disable the Save Changes button until a change has been made */
			/* we won't use this until an AJAX call has been implemented to make
			this fault proof
			$(this).attr('disabled', 'disabled');
			$(this).addClass('foswikiSubmitDisabled');
			$(this).removeClass('foswikiSubmit');
			*/
		} else {
			$(this).addClass('foswikiHidden');
		}
	});
	$(".showWhenNothingChanged").each(function() {
		showWhenNothingChangedElements.push(this);
	});
	$(".tabli a").each(function() {
    	var sectionParts = getSectionParts(this.hash);
		this.sectionId = sectionParts.main;
		if (sectionParts.sub) {
			this.sectionId = sectionParts.sub;
			setDefaultSub(sectionParts.main, sectionParts.sub);
		}
		tabLinks[this.sectionId] = $(this).parent().get(0);
  	});
  	$(".tabli a").click(function() {
		return showSection(this.sectionId);
	});
	$("a.configureExpert").click(function() {
		toggleExpertsMode();
		return false;
	});
	$("a.configureNotExpert").click(function() {
		toggleExpertsMode();
		return false;
	});
	$("a.configureInfoText").click(function() {
		toggleInfoMode();
		return false;
	});
	$("a.configureNotInfoText").click(function() {
		toggleInfoMode();
		return false;
	});
	$("a.configureDefaultValueLink").each(function() {
		initDefaultLink(this);
	});
	$("a.configureDefaultValueLink", $("div.configureRootSection")).mouseover(function() {
		showDefaultLinkToolTip(this);
	});
	$(".configureToggleSections a").click(function() {
		toggleSections();
	});
	$("input.foswikiFocus").each(function() {
		this.focus();
	});
	toggleExpertsMode();
	toggleInfoMode();
	initSection();
	$(".extensionRow").extensionImage();
});

