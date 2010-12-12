/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

*/

/**
 * Support for string manipulation
 * Requires: JQUERYPLUGIN::FOSWIKI
 */

foswiki.String = {
		
	/**
     * Checks if a string is a WikiWord.
     * @param inValue : string to test
     * @return True if a WikiWord, false if not.
     */
	isWikiWord:function(inValue) {
		if (!inValue) return false;
		var re = new RegExp(foswiki.StringConstants.getInstance()
                            .WIKIWORD_REGEX);
		return (inValue.match(re)) ? true : false;
	},

	/**
     * Capitalizes words in the string. For example: "A handy dictionary"
     * becomes "A Handy Dictionary".
     * @param inValue : (String) text to convert
     * @return The capitalized text.
     */
	capitalize:function(inValue) {
		if (!inValue) return null;
		var re = new RegExp(
            "[" + foswiki.StringConstants.getInstance().MIXED_ALPHANUM_CHARS
            + "]+", "g");
		return inValue.replace(re, function(a) {
			return a.charAt(0).toLocaleUpperCase() + a.substr(1);
		});
	},
	
	/**
     * Checks if a string is a 'boolean string'.
     * @param inValue : (String) text to check
     * Returns True if the string is either "on", "true" or "1";
     *  otherwise: false.
     */
	isBoolean:function(inValue) {
		return (inValue == "on") || (inValue == "true") || (inValue == "1");
	},

	/**
     * Removes spaces from a string. For example: "A Handy Dictionary"
     *  becomes "AHandyDictionary".
     * @param inValue : the string to remove spaces from
     * @return A new string free from spaces.
     */
	removeSpaces:function(inValue) {
		return inValue.replace(/\s/g, '');
	},
	
	trimSpaces:function(inValue) {
    	if (inValue) {
    		inValue = inValue.replace(/^\s\s*/, '');
		}
		if (inValue) {
			inValue = inValue.replace(/\s\s*$/, '');
		}
		return inValue;
	},
	
	/**
     * Removes filtered punctuation characters from a string by stripping all characters
     * identified in the Foswiki::cfg{NameFilter} passed as NAMEFILTER+.
     * @param inValue : the string to remove chars from
     * @return A new string free from punctuation characters.
     */
	filterPunctuation:function(inValue) {
		if (!inValue) return null;
        var nameFilterRegex = foswiki.getPreference('NAMEFILTER')
		var re = new RegExp(nameFilterRegex, "g");
		return inValue.replace(re, " ");
	},

	/**
     * Removes punctuation characters from a string by stripping all characters
     * except for MIXED_ALPHANUM_CHARS. For example: "A / Z" becomes "AZ".
     * @param inValue : the string to remove chars from
     * @return A new string free from punctuation characters.
     */
	removePunctuation:function(inValue) {
		if (!inValue) return null;
		var allowedRegex = "[^" + foswiki.StringConstants.getInstance()
        .MIXED_ALPHANUM_CHARS + "]";
		var re = new RegExp(allowedRegex, "g");
		return inValue.replace(re, "");
	},
	
	/**
     * Creates a WikiWord from a string. For example: "A handy dictionary"
     * becomes "AHandyDictionary".
     * @param inValue : (String) the text to convert to a WikiWord
     * @return A new WikiWord string.
     */
	makeWikiWord:function(inValue) {
		if (!inValue) return null;
		return foswiki.String.removePunctuation(foswiki.String.capitalize(inValue));
	},
	
	/**
     * Makes a text safe to insert in a Foswiki table. Any table-breaking
     * characters are replaced.
     * @param inText: (String) the text to make safe
     * @return table-safe text.
     */
	makeSafeForTableEntry:function(inText) {
		if (inText.length == 0) return "";
		var safeString = inText;
		var re;
		// replace \n by \r
		re = new RegExp(/\r/g);
		safeString = safeString.replace(re, "\n");	
		// replace pipes by forward slashes
		re = new RegExp(/\|/g);
		safeString = safeString.replace(re, "/");
		// replace double newlines
		re = new RegExp(/\n\s*\n/g);
		safeString = safeString.replace(re, "%<nop>BR%%<nop>BR%");
		// replace single newlines
		re = new RegExp(/\n/g);
		safeString = safeString.replace(re, "%<nop>BR%");
		// make left-aligned by appending a space
		safeString += " ";
		return safeString;
	}
}


/**
 * Unicode conversion tools:
 * Convert text to hexadecimal Unicode escape sequence (\uXXXX)
 * http://www.hot-tips.co.uk/useful/unicode_converter.HTML
 * Convert hexadecimal Unicode escape sequence (\uXXXX) to text
 * http://www.hot-tips.co.uk/useful/unicode_convert_back.HTML
 * 	
 * More international characters in foswikiStringUnicodeChars.js
 * Import file when international support is needed:
 * <script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JavascriptFiles/foswikiStringUnicodeChars.js"></script>
 * foswikiStringUnicodeChars.js will overwrite the regexes below:
 * 
 * Info on unicode: http://www.fileformat.info/info/unicode/
 */
	
foswiki.StringConstants = function () {
	this.init();
}
foswiki.StringConstants.__instance__ = null; // define the static property
foswiki.StringConstants.getInstance = function () {
	if (this.__instance__ == null) {
		this.__instance__ = new foswiki.StringConstants();
	}
	return this.__instance__;
}
foswiki.StringConstants.prototype.UPPER_ALPHA_CHARS = "A-Z";

foswiki.StringConstants.prototype.LOWER_ALPHA_CHARS = "a-z";
foswiki.StringConstants.prototype.NUMERIC_CHARS = "\\d";

foswiki.StringConstants.prototype.MIXED_ALPHA_CHARS;
foswiki.StringConstants.prototype.MIXED_ALPHANUM_CHARS;
foswiki.StringConstants.prototype.LOWER_ALPHANUM_CHARS;
foswiki.StringConstants.prototype.WIKIWORD_REGEX;
foswiki.StringConstants.prototype.ALLOWED_URL_CHARS;

foswiki.StringConstants.prototype.init = function () {
	foswiki.StringConstants.prototype.MIXED_ALPHA_CHARS =
    foswiki.StringConstants.prototype.LOWER_ALPHA_CHARS
    + foswiki.StringConstants.prototype.UPPER_ALPHA_CHARS;
	
	foswiki.StringConstants.prototype.MIXED_ALPHANUM_CHARS =
    foswiki.StringConstants.prototype.MIXED_ALPHA_CHARS
    + foswiki.StringConstants.prototype.NUMERIC_CHARS;
	
	foswiki.StringConstants.prototype.LOWER_ALPHANUM_CHARS =
    foswiki.StringConstants.prototype.LOWER_ALPHA_CHARS
    + foswiki.StringConstants.prototype.NUMERIC_CHARS;
	
	foswiki.StringConstants.prototype.WIKIWORD_REGEX =
    "^" + "[" + foswiki.StringConstants.prototype.UPPER_ALPHA_CHARS + "]"
    + "+" + "[" + foswiki.StringConstants.prototype.LOWER_ALPHANUM_CHARS + "]"
    + "+" + "[" + foswiki.StringConstants.prototype.UPPER_ALPHA_CHARS + "]"
    + "+" + "[" + foswiki.StringConstants.prototype.MIXED_ALPHANUM_CHARS + "]"
    + "*";
	
	foswiki.StringConstants.prototype.ALLOWED_URL_CHARS =
    foswiki.StringConstants.prototype.MIXED_ALPHANUM_CHARS + "-_^";
};
