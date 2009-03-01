package Foswiki::Configure::CSS;

use strict;

use vars qw( $css );

sub css {
    local $/ = undef;
    return <DATA>;
}

1;
__DATA__
.foswikiLeft{float:left;position:relative;}.foswikiRight{position:relative;float:right;display:inline;margin:0;}.foswikiClear{height:0;line-height:0;clear:both;display:block;margin:0;padding:0;}.foswikiSmall{font-size:86%;line-height:1.5em;}.foswikiSmallish{font-size:94%;line-height:1.5em;}.foswikiBroadcastMessage{background-color:#ff0;background-image:url(background_alert.gif);background-repeat:repeat-x;margin:0 0 1.25em;padding:.25em .5em;}.foswikiEmulatedLink{text-decoration:underline;color:#4571d0;}.foswikiAccessKey{text-decoration:none;border:none;color:inherit;border-color:#777;border-style:solid;border-width:0 0 1px;}a:hover .foswikiAccessKey{border:none;text-decoration:none;color:inherit;border-style:solid;border-width:0 0 1px;}.foswikiImage img{background-color:#fff;border-color:#eee;border-style:solid;border-width:1px;padding:3px;}.foswikiPreviewArea{height:1%;background-color:#fff;border-color:red;border-style:solid;border-width:1px;margin:0 0 2em;padding:1em;}body{voice-family:inherit;font-size:small;background-color:#fff;color:#000;}html>body{font-size:small;}h1,h2,h3,h4,h5,h6{font-weight:400;line-height:1em;}th{line-height:1.15em;}label{padding:.15em .3em .15em 0;}hr{height:1px;border:none;color:#e2e2e2;background-color:#e2e2e2;}pre{width:auto;height:1%;background:#f5f5f5;border-color:#ddd;border-style:solid;border-width:1px;margin:1em 0;padding:1em;}html>body pre{overflow:auto!important;width:auto;}ol li,ul li{line-height:1.4em;}form{display:inline;margin:0;padding:0;}textarea,input,select{vertical-align:middle;font-family:arial, verdana, sans-serif;font-size:100%;color:#000;background-color:#fff;border-color:#aaa;}textarea{font-size:100%;padding:1px;}.foswikiPage{font-family:arial, sans-serif;line-height:1.4em;font-size:105%;background:#fff;padding:1em;}.foswikiNewLink a:link sup,.foswikiNewLink a:visited sup{text-decoration:none;color:#777;border-color:#ddd;border-style:solid;border-width:1px;}.foswikiNewLink a:hover sup{text-decoration:none;background-color:#0055b5;color:#fff;border-color:#0055b5;}.foswikiNewLink{border-color:#ddd;border-style:solid;border-width:0 0 1px;}:link:focus,:visited:focus,:link,:visited,:link:active,:visited:active{text-decoration:underline;color:#4571d0;background-color:transparent;}:link:hover,:visited:hover{text-decoration:none;color:#fff;background-color:#0055b5;background-image:none;}.foswikiSubmit,.foswikiButton,.foswikiCheckbox{padding:.1em .3em;}.foswikiCheckbox,.foswikiRadioButton{border:0;margin:1px .25em 1px .1em;padding:0 0 0 .5em;}.foswikiTable th{background-color:#9be;border-color:#ccc;border-style:none solid;border-width:0 0 0 1px;padding:4px 6px;}.foswikiAttachments table,table.foswikiFormTable{border-collapse:collapse;border-spacing:0;empty-cells:show;background-color:#fff;border-color:#e2e2e2;border-style:solid;border-width:1px;margin:5px 0;padding:0;}.foswikiAttachments table{voice-family:inherit;line-height:1.5em;width:100%;background-color:#fff;}.foswikiAttachments .foswikiTable th font{color:#06c;}.foswikiFormSteps{text-align:left;background-color:#eef7fa;border-color:#e2e2e2;border-style:solid;border-width:1px 0 0;padding:.25em 0 0;}.foswikiFormStep{line-height:140%;border-color:#e2e2e2;border-style:solid;border-width:0 0 1px;padding:1em 40px;}.foswikiToc .foswikiTocTitle{font-weight:700;color:#777;margin:0;padding:0;}.foswikiPageForm table{width:100%;background:#fff;border-color:#e2e2e2;border-style:solid;border-width:1px;}.foswikiPageForm hr{background-color:#cfcfcf;color:#cfcfcf;border-color:#cfcfcf;}.foswikiHelp{height:1%;background-color:#edf5fa;border-color:#e2e2e2;border-style:solid;border-width:2px;margin:.25em 0 0;padding:1em;}table#foswikiSearchTable th,table#foswikiSearchTable td{background-color:#fff;border-color:#e2e2e2;}table#foswikiSearchTable td.first{background-color:#FCF8EC;}tr.foswikiDiffDebug td{border-color:#e2e2e2;border-style:solid;border-width:1px;}.foswikiDiffChangedHeader,tr.foswikiDiffDebug .foswikiDiffChangedText,tr.foswikiDiffDebug .foswikiDiffChangedText{background:#9f9;}tr.foswikiDiffDebug .foswikiDiffDeletedMarker,tr.foswikiDiffDebug .foswikiDiffDeletedText{background-color:#f99;}.foswikiDiffAddedHeader,tr.foswikiDiffDebug .foswikiDiffAddedMarker,tr.foswikiDiffDebug .foswikiDiffAddedText{background-color:#ccf;}.foswikiDiffLineNumberHeader{background-color:#ccc;padding:.3em 0;}.foswikiNewLink a{text-decoration:none;margin-left:1px;}.foswikiNewLink a sup{text-align:center;vertical-align:baseline;font-size:100%;text-decoration:none;padding:0 2px;}.foswikiTable{border-collapse:collapse;border-style:solid;border-width:1px;margin:2px 0;}.foswikiTable td{border-style:solid none;border-width:0 0 1px;padding:3px 6px;}.foswikiTable th.foswikiFirstCol{border-left-style:none;}.foswikiEditForm{color:#000;margin:0 0 .5em;}.foswikiLast,.foswikiForm .foswikiLast,.foswikiTable .foswikiLast{border-bottom-style:none;border-bottom-width:0;}#foswikiLogin{width:44em;text-align:center;margin:0 auto;}#foswikiLogin .foswikiFormSteps{border-width:5px;}.foswikiAttachments,.foswikiForm{height:1%;margin:1em 0;padding:1px;}.foswikiTable h2,.foswikiFormTable h2,.foswikiTable h3,.foswikiFormTable h3,.foswikiTable h4,.foswikiFormTable h4,.foswikiTable h5,.foswikiFormTable h5,.foswikiTable h6,.foswikiFormTable h6{border:0;padding-left:0;padding-right:0;margin:0;}.foswikiFormTable th{font-weight:400;}table.foswikiFormTable th.foswikiFormTableHRow{text-align:center;}.foswikiAttachments td,table.foswikiFormTable td{height:1.4em;text-align:left;vertical-align:top;padding:3px 6px;}.foswikiFormStep h2,.foswikiFormStep h3,.foswikiFormStep h4{border:none;background:none;margin:0 0 .1em;padding:0;}.foswikiFormStep h2{font-size:130%;font-weight:700;color:#2989bb;}.foswikiFormStep h3{font-size:115%;font-weight:700;}.foswikiFormStep h4{font-size:104%;font-weight:700;}.foswikiFormStep p{margin:.5em 0;}.foswikiFormSteps .foswikiLast{border-bottom-style:solid;border-bottom-width:0;}.foswikiToc{margin:1em 0;padding:.3em 0 .6em;}.foswikiSummary{line-height:110%;font-size:86%;}.foswikiPageForm th,.foswikiPageForm td{border:0;padding:.5em 1em;}.foswikiHelp ul{padding-left:20px;margin:0;}.foswikiWebIndent{margin:0 0 0 1em;}#foswikiSearchTable{background:none;border-bottom:0;}#foswikiSearchTable th,#foswikiSearchTable td{border-style:solid;border-width:0 0 1px;padding:1em;}#foswikiSearchTable th{width:20%;text-align:right;}#foswikiSearchTable td{width:80%;}.foswikiEditboxStyleMono{font-family:"Bitstream Vera Sans Mono","Andale Mono",Courier,monospace;}.foswikiEditboxStyleProportional{font-family:arial, verdana, sans-serif;}html,body{border:0;height:100%;margin:0;padding:0;}body{min-width:100%;text-align:center;}.clear{clear:both;height:0;overflow:hidden;line-height:1%;font-size:0;}#patternWrapper{height:auto;}* html #patternWrapper{height:100%;}#patternPage{margin-left:auto;margin-right:auto;text-align:left;position:relative;width:100%;font-family:arial, verdana, sans-serif;line-height:1.5em;font-size:105%;background-color:#fff;border-color:#ccc;}#patternOuter{z-index:1;position:relative;height:100%;background:none;border-color:#dadada;}#patternFloatWrap{width:100%;float:left;display:inline;}#patternSideBar{float:left;display:inline;overflow:hidden;}#patternSideBarContents{position:relative;padding-right:.5em;padding-left:1em;padding-bottom:2em;color:#000;margin:0 0 1em;}#patternMain{width:100%;float:right;display:inline;}#patternTopBar{z-index:1;position:absolute;top:0;width:100%;border-color:#e2e2e2;border-style:none none solid;border-width:1px;}#patternBottomBar{z-index:1;clear:both;width:100%;background-color:#f5f5f5;border-color:#ccc;border-style:solid;border-width:1px 0 0;}pre,code,tt{font-family:"Bitstream Vera Sans Mono","Andale Mono",Courier,monospace;font-size:86%;color:#333;}blockquote{background-color:#f5f5f5;border-color:#ddd;border-style:solid;border-width:1px 1px 1px 5px;padding:.5em 1.25em;}h1{font-size:190%;color:#2989bb;margin:0 0 .5em;}h2{font-size:153%;border-color:#e2e2e2;}h3{font-size:133%;}h4{font-size:122%;font-weight:700;}h5{font-size:110%;font-weight:700;}h6{font-size:95%;font-weight:700;}h2,h3,h4,h5,h6{display:block;height:auto;color:#d1400e;margin:1em -10px .35em;padding:.25em 10px;}h1.patternTemplateTitle{font-size:170%;text-align:center;}h2.patternTemplateTitle{text-align:center;margin-top:.5em;background:none;border:none;}img{vertical-align:text-bottom;border:0;}.foswikiSubmit,.foswikiSubmitDisabled,.foswikiButton,.foswikiButtonDisabled,.foswikiButtonCancel,a.foswikiButton,a.foswikiSubmit,a.foswikiButtonCancel,.foswikiCheckbox{font-weight:700;vertical-align:middle;text-align:center;border-style:solid;border-width:1px;padding:.1em .2em;}.foswikiSubmit,.foswikiSubmitDisabled,.foswikiButton,.foswikiButtonDisabled,.foswikiButtonCancel,.foswikiSubmit:hover,.foswikiSubmitDisabled:hover,.foswikiButton:hover,.foswikiSubmit:active,.foswikiSubmitDisabled:active,.foswikiButton:active{cursor:default;outline:none;}.foswikiTextarea,.foswikiInputField,.foswikiInputFieldDisabled,.foswikiInputFieldReadOnly,.foswikiSelect{border-color:#bbb #f2f2f2 #f2f2f2 #bbb;border-style:solid;border-width:2px;}.foswikiTextarea,.foswikiInputField,.foswikiInputFieldDisabled,.foswikiInputFieldReadOnly{font-size:100%;}.tagMePlugin select{margin:0 .25em 0 0;}.tagMePlugin input{border:0;}.patternEditPage .revComment{padding:1em 0 2em;}.editTable .foswikiTable{margin:0 0 2px;}.foswikiTable,.foswikiTable td,.foswikiTable th{border-color:#e2e2e2;border-width:1px;}.foswikiTable .tableSortIcon{margin:0 0 0 5px;}.tipsOfTheDay{padding:10px;}#foswikiLogin .patternLoginNotification{padding-left:.5em;padding-right:.5em;background-color:#fff;border-color:red;border-style:solid;border-width:2px;}.patternEditPage .foswikiFormTable td,.patternEditPage .foswikiFormTable th{vertical-align:middle;border-style:solid;border-width:0 0 1px;padding:.3em .4em;}.patternContent .foswikiAttachments,.patternContent .foswikiForm{font-size:94%;background-color:#eef7fa;border-color:#fff;border-style:solid;border-width:2px 0 0;margin:0;padding:1em 20px;}.foswikiAttachments .foswikiTable,table.foswikiFormTable{border-collapse:collapse;border-spacing:0;empty-cells:show;border-style:solid;border-width:1px;margin:10px 0 5px;padding:0;}.foswikiAttachments .foswikiTable td,table.foswikiFormTable td{height:1.5em;text-align:left;vertical-align:top;padding:3px 2em 3px 1em;}.foswikiAttachments h3,.foswikiForm h3,.patternTwistyButton h3{font-size:1.1em;font-weight:700;display:inline;margin:0;padding:0;}.patternTwistyButton h3{color:#d1400e;padding:.1em .2em;}.patternSmallLinkToHeader{font-weight:400;font-size:86%;margin:0 0 0 .15em;}.foswikiFormStep blockquote{margin-left:1em;padding-top:.25em;padding-bottom:.25em;}.foswikiActionFormStepSign{position:absolute;font-size:104%;margin-left:-20px;margin-top:-.15em;color:#d1400e;}.foswikiToc ul{list-style:none;margin:0;padding:0 0 0 .5em;}.foswikiToc li{margin-left:1em;padding-left:1em;background-image:url(bullet-toc.gif);background-repeat:no-repeat;background-position:0 .4em;}.foswikiBroadcastMessage,.foswikiNotification{background-color:#fff7e1;padding:1em 20px;}.foswikiNotification{border:2px solid #ffdf4c;border-style:solid;border-width:2px;margin:1em 0;}#foswikiLogo img{border:0;margin:0;padding:0;}.foswikiNoBreak{white-space:nowrap;}.patternNoViewPage #patternOuter,.patternPrintPage #patternOuter{margin-left:0;margin-right:0;}#patternWebBottomBar{font-size:94%;line-height:125%;text-align:left;}#patternMainContents,#patternBottomBarContents,#patternSideBarContents,#patternTopBarContents{padding-right:2em;padding-left:2em;}#patternSideBarContents,#patternMainContents{padding-top:2em;}#patternBottomBarContents{padding-top:1em;padding-bottom:2em;}.patternNoViewPage .foswikiTopic{margin-top:1em;}#patternMainContents{padding-bottom:4em;}.foswikiTopic{margin:0 0 2em;}.patternNoViewPage #patternMainContents,.patternNoViewPage #patternBottomBarContents{margin-left:4%;margin-right:4%;}.patternEditPage #patternMainContents,.patternEditPage #patternBottomBarContents{margin-left:2%;margin-right:2%;}.patternTop{margin:0 0 .5em;}.patternNoViewPage .patternTop{font-size:94%;}#patternSideBarContents img{vertical-align:text-bottom;margin:0 3px 0 0;}#patternSideBarContents a:link,#patternSideBarContents a:visited{text-decoration:none;color:#444;}#patternSideBarContents,#patternSideBarContents ul,#patternSideBarContents li{line-height:1.35em;}#patternSideBarContents h2{border:none;background-color:transparent;}#patternSideBarContents .patternLeftBarPersonal,#patternSideBarContents .patternWebIndicator{height:1%;width:100%;border-color:#dadada;border-style:none none solid;border-width:1px;margin:0 -1em .75em;padding:0 1em .75em;}.patternWebIndicator a{font-size:1.1em;font-weight:700;}.patternLeftBarPersonalContent{padding:1em 0 0;}#patternSideBarContents li{overflow:hidden;}html>body #patternSideBarContents li{overflow:visible;}.patternMetaMenu select option{padding:1px 0 0;}.patternMetaMenu ul li{display:inline;padding:0;}.patternMetaMenu ul li .foswikiInputField,.patternMetaMenu ul li .foswikiSelect{margin:0 0 0 .5em;}.patternHomePath .foswikiSeparator{padding:0 .5em;}.patternHomePath a:link,.patternHomePath a:visited{text-decoration:none;color:#666;border-color:#ddd;border-style:none none solid;border-width:1px;}.patternToolBar span{float:left;}.patternToolBar span s,.patternToolBar span strike,.patternToolBar span a:link,.patternToolBar span a:visited{display:block;font-weight:700;border-style:solid;border-width:1px;margin:0 0 .2em .25em;padding:.1em .35em;}.patternToolBar span a:link,.patternToolBar span a:visited{text-decoration:none;outline:none;background-position:0 0;background-color:#cce7f1;color:#333;border-color:#fff #94cce2 #94cce2 #fff;}.patternToolBar span a:hover,.patternToolBar span a:hover{border-style:solid;border-width:1px;}.patternToolBar span a:active{outline:none;background-position:0 -160px;background-color:#e8e5d7;color:#222;border-color:#94cce2;}.patternToolBar span s,.patternToolBar span strike{text-decoration:none;background-position:0 -240px;background-color:#edece6;color:#bbb;border-color:#eae9e7;}.patternTopicActions{border:none;background-color:#2989bb;color:#bbb;}.patternTopicAction{line-height:1.5em;height:1%;border-color:#fff;border-style:solid;border-width:1px 0 0;padding:.4em 20px;}.patternOopsPage .patternTopicActions,.patternEditPage .patternTopicActions{margin:2em 0 0;}.patternAttachPage .patternTopicAction,.patternRenamePage .patternTopicAction{padding-left:40px;}.patternActionButtons a:link,.patternActionButtons a:visited{color:#fff;padding:1px 1px 2px;}.patternNoViewPage .patternTopicAction{margin-top:-1px;}.patternInfo{margin:1.5em 0 0;}.patternHomePath .patternRevInfo{font-size:94%;white-space:nowrap;}.patternMoved{margin:1em 0;}.patternMoved i,.patternMoved em{font-style:normal;}.patternSearchResults{margin:0 0 1em;}.patternSearchResults blockquote{margin:1em 0 1em 5em;}h3.patternSearchResultsHeader,h4.patternSearchResultsHeader{display:block;height:1%;font-weight:700;background-color:#eef7fa;border-color:#e2e2e2;border-style:solid;border-width:0 0 1px;}.patternSearchResults h3{font-size:115%;font-weight:700;margin:0;padding:.5em 40px;}h4.patternSearchResultsHeader{font-size:100%;padding-top:.3em;padding-bottom:.3em;font-weight:400;color:#000;}.patternSearchResult .foswikiTopRow{padding-top:.2em;margin-top:.1em;}.patternSearchResult .foswikiBottomRow{margin-bottom:.1em;padding-bottom:.25em;border-color:#e2e2e2;border-style:solid;border-width:0 0 1px;}.patternSearchResult .foswikiAlert{font-weight:700;color:red;}.patternSearchResult .foswikiSummary .foswikiAlert{font-weight:400;color:#900;}.patternSearchResult .foswikiNew{font-size:86%;font-weight:700;background-color:#ECFADC;color:#049804;border-color:#049804;border-style:solid;border-width:1px;padding:0 1px;}.patternSearchResults .foswikiHelp{display:block;width:auto;margin:1em -5px .35em;padding:.1em 5px;}.patternSearchResult .foswikiSRAuthor{width:15%;text-align:left;}.patternSearchResult .foswikiSRRev{width:30%;text-align:left;}.patternSearchResultCount{margin:1em 0 3em;}.patternSearched{display:block;}.patternBookView{border-style:solid;border-width:0 0 2px 2px;margin:.5em 0 1.5em -5px;padding:0 0 0 5px;}.patternBookView .foswikiTopRow{background-color:transparent;color:#777;margin:1em -5px .15em;padding:.25em 5px .15em;}.patternBookView .foswikiBottomRow{font-size:100%;width:auto;border:none;border-color:#e2e2e2;padding:1em 0;}.patternEditPage #patternMainContents{padding:0 0 2em;}.patternEditPage .patternEditTopic{margin:0 0 .5em;padding:5px;}.foswikiFormHolder{width:100%;}.patternEditPage .foswikiForm h1,.patternEditPage .foswikiForm h2,.patternEditPage .foswikiForm h3{font-size:120%;font-weight:700;}.patternSig{text-align:right;}.patternSigLine{height:1%;color:#777;border-style:none;margin:.5em 0 0;}.foswikiAddFormButton{float:right;}.patternTextareaButton{display:block;cursor:pointer;overflow:hidden;border-color:#fffefd #b8b6ad #b8b6ad #fffefd;border-style:solid;border-width:1px;margin:0 0 0 1px;}.patternButtonFontSelector{background-image:url(button_font_selector.gif);width:33px;height:16px;margin:0 8px 0 0;}.patternSaveHelp{line-height:1.5em;margin:1em 0 0;}.patternSaveOptions{clear:both;margin:.25em 0 0;}.patternAttachPage .foswikiAttachments .foswikiTable{width:auto;}.patternMoveAttachment{text-align:right;margin:.5em 0 0;}.patternDiff{border-color:#6b7f93;border-style:solid;border-width:0 0 2px 2px;margin:.5em 0 1.5em;padding:0 0 0 10px;}.patternDiff h4.patternSearchResultsHeader{padding:.5em 10px;}.patternDiffPage .patternRevInfo ul{list-style:none;margin:2em 0 0;padding:0;}.patternDiffPage .foswikiDiffTable{margin:2em 0;}.patternDiffPage td.foswikiDiffDebugLeft{border-bottom:none;}.patternDiffPage .foswikiDiffTable th{background-color:#ccc;padding:.25em .5em;}.patternDiffPage .foswikiDiffTable td{padding:.25em;}#patternScreen{background:#e2e2e2;}html body.patternEditPage,.mceContentBody{background-color:#fff;}.foswikiTopic a:visited{color:#666;}#patternMainContents h1 a:link,#patternMainContents h1 a:visited{color:#2989bb;}.foswikiSubmit,.foswikiButton{border-color:#fff #888 #888 #fff;}.foswikiSubmit{color:#fff;background-color:#06c;}.foswikiButton{color:#000;background-color:#e2e3e3;}.foswikiButtonCancel{background-color:#dd724d;color:#fff;border-color:#f3ddd7 #ce5232 #ce5232 #f3ddd7;}.foswikiSubmitDisabled,.foswikiSubmitDisabled:active{color:#aaa;background-color:#eef7fa;border-color:#fff #ccc #ccc #fff;}.foswikiTextarea,.foswikiInputField,.foswikiSelect{color:#000;background-color:#fff;}.foswikiInputField:active,.foswikiInputField:focus,.foswikiInputFieldFocus{background-color:#ffffe0;}.foswikiInputFieldDisabled{color:#aaa;background-color:#fafaf8;}.foswikiSelect{color:#000;background-color:#fff;border-color:#bbb #f2f2f2 #f2f2f2 #bbb;}.foswikiInputFieldDisabled,.foswikiSelectDisabled{color:#aaa;background-color:#fafaf8;border-color:#bbb #f2f2f2 #f2f2f2 #bbb;}.revComment .patternTopicAction{background-color:#eef7fa;}.foswikiEditForm .foswikiFormTable td{background-color:#f7fafc;}.foswikiEditForm .foswikiFormTable th{background-color:#f0f6fb;}.foswikiFormStep h3,.foswikiFormStep h4{color:#d1400e;background-color:transparent;}.foswikiImage a:hover img{border-color:#0055b5;}.patternTop a:hover{border:none;color:#fff;}#patternSideBarContents hr{color:#e2e2e2;background-color:#e2e2e2;}.patternTopicAction s,.patternTopicAction strike{color:#aaa;}.patternTopicAction .foswikiSeparator{color:#e2e2e2;}.patternTopicAction a:link .foswikiAccessKey,.patternTopicAction a:visited .foswikiAccessKey{color:#fff;border-color:#fff;}.patternEditTopic{background:#eef7fa;}.patternToolBar a:link .foswikiAccessKey,.patternToolBar a:visited .foswikiAccessKey{color:inherit;border-color:#666;}.patternToolBar a:hover .foswikiAccessKey{background-color:transparent;color:inherit;border-color:#666;}table#foswikiSearchTable hr{background-color:#e2e2e2;border-color:#e2e2e2;}#patternMainContents .patternDiff h4.patternSearchResultsHeader{background-color:#6b7f93;color:#fff;}.foswikiSubmit,.foswikiSubmitDisabled{}.foswikiSubmit,a.foswikiSubmit:link,a.foswikiSubmit:visited{background-position:0 0;background-color:#06c;color:#fff;border-color:#94cce2 #0e66a2 #0e66a2 #94cce2;}.foswikiSubmit:hover,a.foswikiSubmit:hover{background-position:0 -80px;background-color:#0047b7;color:#fff;border-color:#0e66a2 #94cce2 #94cce2 #0e66a2;}.foswikiSubmit:active,a.foswikiSubmit:active{background-position:0 -160px;background-color:#73ace6;color:#fff;border-color:#0e66a2 #94cce2 #94cce2 #0e66a2;}.foswikiSubmitDisabled,.foswikiSubmitDisabled:hover,.foswikiSubmitDisabled:active{background-position:0 -240px;background-color:#d9e8f7;color:#ccc;border-color:#ccc;}.foswikiButton,a.foswikiButton:link,a.foswikiButton:visited{background-color:#cce7f1;color:#333;border-color:#fff #94cce2 #94cce2 #fff;}.foswikiButton:hover,.foswikiButton:active,a.foswikiButton:hover,a.foswikiButton:active{background-position:0 -160px;background-color:#cce7f1;color:#333;border-color:#94cce2;}.foswikiButtonDisabled,.foswikiButtonDisabled:hover,.foswikiButtonDisabled:active{background-color:#edece6;color:#bbb;border-color:#ccc;}.foswikiButtonCancel:hover{background-position:0 -80px;background-color:#dd724d;color:#fff;border-color:#ce5232 #f3ddd7 #f3ddd7 #ce5232;}.foswikiButtonCancel:active{background-position:0 -160px;background-color:#dd724d;color:#fff;border-color:#ce5232 #f3ddd7 #f3ddd7 #ce5232;}.patternToolBar span a:link,.patternToolBar span a:visited,.patternToolBar span s,.patternToolBar span strike{}.patternToolBar span a:hover{background-position:0 -80px;background-color:#cce7f1;color:#222;border-color:#94cce2;}.patternButtonFontSelectorMonospace{background-position:0 -16px;}.patternButtonEnlarge,.patternButtonShrink{background-image:url(button_arrow.gif);width:16px;height:16px;}.patternButtonEnlarge:hover{background-position:0 -42px;}.patternButtonEnlarge:active{background-position:0 -84px;}.patternButtonShrink{background-position:16px 0;}.patternButtonShrink:hover{background-position:16px -42px;}.patternButtonShrink:active{background-position:16px -84px;}.patternLeftBarPersonal li,li.patternLogOut,li.patternLogIn{padding-left:13px;background-position:0 .4em;background-repeat:no-repeat;}.patternLeftBarPersonal li{background-image:url(bullet-personal_sidebar.gif);}.foswikiMakeVisible,.foswikiMakeVisibleInline,.foswikiMakeVisibleBlock,.foswikiHidden,.foswikiAttachments caption,.foswikiAttachments .foswikiTable caption{display:none;}.foswikiBroadcastMessage b,.foswikiBroadcastMessage strong,.foswikiAlert,.foswikiAlert code{color:red;}p,.foswikiCopyright,.patternTopicFooter{margin:1em 0 0;}strong,b,.foswikiFormTable .foswikiTable th,.foswikiHierarchicalNavigation .foswikiCurrentTopic li,.foswikiSearchResultCount{font-weight:700;}ol,ul,.patternAttachPage .foswikiAttachments{margin-top:0;}input,select option,.foswikiTextarea{padding:1px;}.foswikiNewLink font,a:link .foswikiAccessKey,a:visited .foswikiAccessKey,a:hover .foswikiAccessKey,a:link .foswikiAccessKey,a:visited .foswikiAccessKey{color:inherit;}:link:hover img,:visited:hover img,body,p,li,ul,ol,dl,dt,dd,acronym,h1,h2,h3,h4,h5,h6,#patternTopBar .foswikiImage img{background-color:transparent;}.foswikiTable,.foswikiTable td,.foswikiAttachments td,.foswikiAttachments th{border-color:#ccc;}.foswikiTable th a:link,.foswikiTable th a:visited,.foswikiTable th a font,.foswikiGrayText a:hover,#patternBottomBarContents a:hover,.foswikiTopic a:hover,#patternMainContents h1 a:hover,#patternMainContents h2 a:hover,#patternMainContents h3 a:hover,#patternMainContents h4 a:hover,#patternMainContents h5 a:hover,#patternMainContents h6 a:hover,.foswikiTopic .foswikiUnvisited a:hover,a:hover.twistyTrigger,.patternHomePath .patternRevInfo a:hover,#patternSideBarContents a:hover,.patternActionButtons a:hover,.patternTopicAction a:hover .foswikiAccessKey,#patternMainContents .patternDiff h4.patternSearchResultsHeader a:link,#patternMainContents .patternDiff h4.patternSearchResultsHeader a:visited{color:#fff;}.foswikiGrayText,.foswikiGrayText a:link,.foswikiGrayText a:visited,#patternBottomBarContents,#patternBottomBarContents a:link,#patternBottomBarContents a:visited,.foswikiInputFieldReadOnly,.foswikiInputFieldBeforeFocus,.twistyPlaceholder,table.foswikiFormTable th.foswikiFormTableHRow,table.foswikiFormTable td.foswikiFormTableRow,.patternHomePath .patternRevInfo,.patternHomePath .patternRevInfo a:link,.patternHomePath .patternRevInfo a:visited,.patternHelpCol,.patternBookView .patternSearchResultCount,tr.foswikiDiffDebug .foswikiDiffUnchangedText{color:#777;}.foswikiSeparator,.foswikiDiffUnchangedHeader,tr.foswikiDiffDebug .foswikiDiffUnchangedText{color:#8E9195;}table#foswikiSearchTable th,.foswikiTextareaRawView,.patternTopicAction label{color:#000;}.foswikiTable a:link,.foswikiTable a:visited,.foswikiTable a:hover{text-decoration:underline;}.foswikiAttachments th,.foswikiAttachments .foswikiTable th{border-style:none none solid solid;border-width:1px;}.foswikiAttachments th,table.foswikiFormTable th.foswikiFormTableHRow,.foswikiAttachments .foswikiTable th,table.foswikiFormTable th.foswikiFormTableHRow{height:2.5em;vertical-align:middle;padding:3px 6px;}.foswikiAttachments th.foswikiFirstCol,.foswikiAttachments td.foswikiFirstCol,.foswikiAttachments .foswikiTable th.foswikiFirstCol,.foswikiAttachments .foswikiTable td.foswikiFirstCol{width:26px;text-align:center;}table.foswikiFormTable th.foswikiFormTableHRow a:link,table.foswikiFormTable th.foswikiFormTableHRow a:visited,a.foswikiButton,a.foswikiButton:hover,a.foswikiButton:link:active,a.foswikiButton:visited:active,a.foswikiButtonCancel,a.foswikiButtonCancel:hover,a.foswikiButtonCancel:link:active,a.foswikiButtonCancel:visited:active,a.foswikiSubmit,a.foswikiSubmit:hover,a.foswikiSubmit:link:active,a.foswikiSubmit:visited:active,.twistyTrigger a:link,.twistyTrigger a:visited,.twistyTrigger a:link .foswikiLinkLabel,.twistyTrigger a:visited .foswikiLinkLabel,.foswikiForm h3 a:link,.foswikiForm h3 a:visited,.patternTopicAction .patternActionButtons a:link,.patternTopicAction .patternActionButtons a:visited,.patternTopicAction .patternActionButtons span s,.patternTopicAction .patternActionButtons span strike{text-decoration:none;}.foswikiPageForm td.first,#patternTopBarContents{padding-top:1em;}.foswikiHelp ul,.foswikiHelp li,.patternMetaMenu input,.patternMetaMenu select,.patternMetaMenu select option{margin:0;}.foswikiHierarchicalNavigation ul,#patternSideBarContents ul,.patternMetaMenu ul{list-style:none;margin:0;padding:0;}.foswikiInputField,.foswikiInputFieldDisabled,.foswikiInputFieldReadOnly,.patternActionButtons a.foswikiButton,.patternActionButtons a.foswikiSubmit,.patternActionButtons a.foswikiButtonCancel{padding:.1em .2em;}.editTableEditImageButton,.patternEditPage .foswikiForm{border:none;}.foswikiImage a:link,.foswikiImage a:visited,blockquote h2{background:none;}.patternEditPage .patternActionButtons,.patternSaveOptionsContents{margin:.5em 0 0;}#patternSideBar,#patternWrapper,.patternPrintPage #patternOuter{background:#fff;}h3,h4,h5,h6,.foswikiEditForm .foswikiFormTable,.foswikiEditForm .foswikiFormTable th,.foswikiEditForm .foswikiFormTable td,.foswikiForm td,.foswikiForm th,.foswikiAttachments td,.foswikiAttachments th,table#foswikiSearchTable,.patternViewPage .patternSearchResultsBegin{border-color:#e2e2e2;}#patternMainContents h2 a:link,#patternMainContents h2 a:visited,#patternMainContents h3 a:link,#patternMainContents h3 a:visited,#patternMainContents h4 a:link,#patternMainContents h4 a:visited,#patternMainContents h5 a:link,#patternMainContents h5 a:visited,#patternMainContents h6 a:link,#patternMainContents h6 a:visited,#patternSideBarContents b,#patternSideBarContents strong,.patternNoViewPage h4.patternSearchResultsHeader{color:#d1400e;}.foswikiTopic .foswikiUnvisited a:visited,.foswikiAttachments .foswikiTable th font,table.foswikiFormTable th.foswikiFormTableHRow font{color:#4571d0;}.patternButtonFontSelectorProportional,.patternButtonEnlarge{background-position:0 0;}.patternLeftBarPersonal li.patternLogOut,.patternLeftBarPersonal li.patternLogIn{background-image:url(bullet-lock.gif);}

/*	----------------------------------------------------------------------- */
/* configure styles */
/*	----------------------------------------------------------------------- */

#twikiPassword,
#twikiPasswordChange {
	width:40em;
	margin:1em auto;
}
#twikiPassword .foswikiFormSteps,
#twikiPasswordChange .foswikiFormSteps {
	border-width:5px;
}
div.foldableBlock h1,
div.foldableBlock h2,
div.foldableBlock h3,
div.foldableBlock h4,
div.foldableBlock h5,
div.foldableBlock h6 {
	border:0;
	margin-top:0;
	margin-bottom:0;
}
ul {
    margin-top:0;
    margin-bottom:0;
}
.logo {
    margin:1em 0 1.5em 0;
}
.formElem {
    background-color:#e9ecf2;
    margin:0.5em 0;
    padding:0.5em 1em;
}
.blockLinks {
	margin:.5em 0;
	border-top:1px solid #aaa;
}
.blockLinkAttribute {
    margin-left:0.35em;
}
.blockLinkAttribute a:link,
.blockLinkAttribute a:visited {
	text-decoration:none;
}
a.blockLink {
    display:block;
    padding:0.25em 1em;
    border-bottom:1px solid #aaa;
    border-top:1px solid #f2f4f6;
	font-weight:bold;
}
a:link.blockLink,
a:visited.blockLink {
    text-decoration:none; 
}
a:link:hover.blockLink {}
a:link.blockLinkOff,
a:visited.blockLinkOff {
    background-color:#f2f4f6;
}
a:link.blockLinkOn,
a:visited.blockLinkOn {
    background-color:#06c;
    color:#fff;
	border-bottom-color:#3f4e67;
    border-top-color:#fff;
}
a.blockLink:hover {
    background-color:#06c;
    color:#fff;
    border-bottom-color:#3f4e67;
    border-top-color:#fff;
}
.blockLinkIndicator {
	padding:0 .25em 0 0;
}
a:link.blockLink em,
a:visited.blockLink em {
	font-style:normal;
	color:#aaa;
}
a:hover.blockLink em {
	color:#aaa;
}
div.explanation {
	background-color:#fff9d1;
    padding:0.5em 1em;
    margin:0.5em 0;
}
div.specialRemark {
    background-color:#fff;
    border:1px solid #ccc;
    margin:0.5em;
    padding:0.5em 1em;
}
div.options {
    margin:1em 0;
}
div.foldableBlock {
    border-bottom:1px solid #ccc;
    border-left:1px solid #ddd;
    border-right:1px solid #ddd;
    height:auto;
    width:auto;
    overflow:auto;
}
.foldableBlockOpen {
    display:block;
}
.foldableBlockClosed {
    display:block;
}
div.foldableBlock td {
    padding:0.5em 1em;
    border-top:1px solid #ccc;
    vertical-align:middle;
    line-height:1.2em;
}
div.foldableBlock td.firstCol,
div.foldableBlock td.secondCol {
	border-top-width:6px;
}
div.foldableBlock td.info {
	border-top-style:dashed;
}
.info {
    color:#666; /*T7*/ /* gray */
    background-color:#f8fbfc;
}
.firstInfo {
    color:#000;
    background-color:#fff;
}

.warn {
    color:#f60; /* orange */
    background-color:#FFE8D9; /* light orange */
    border-bottom:1px solid #f60;
}
a.info,
a.warn,
a.error {
	text-decoration:none;
}
.error {
    color:#f00; /*T9*/ /*red*/
    background-color:#FFD9D9; /* pink */
    border-bottom:1px solid #f00;
}
.mandatory,
.mandatory input {
    color:green;
    background-color:#ECFADC;
    font-weight: bold;
}
.mandatory {
    border-bottom:1px solid green;
}
.mandatory input {
    font-weight:normal;
}
.docdata {
    padding-top: 1ex;
    vertical-align: top;
}
.keydata {
    font-weight: bold;
    background-color:#F0F0F0;
    vertical-align: top;
}
.subHead {
    font-weight: bold;
    font-style: italic;
}
.firstCol {
    width: 30%;
    font-weight:bold;
    vertical-align:top;
    color:#d1400e;
}
.secondCol {
}
.hiddenRow {
    display:none;
}
div.noAuthWarning {
	background:#fff;
}

table.extensionsTable {
	margin:1em 0;
}
table.extensionsTable th {
	background:#687684;
	color:#fff;
	border:none;
}
table.extensionsTable th,
table.extensionsTable td {
	padding:.5em;
	line-height:1.2em;
}
table.extensionsTable .odd {
	background:#fff; /*f6fafc*/
}
table.extensionsTable .even {
	background:#fff;
}
table.extensionsTable .uptodate {
	background:#e8f9e8;
}
table.extensionsTable .upgrade {
	background:#fff0f2;
}
table.extensionsTable .installed a:link,
table.extensionsTable .installed a:visited {
	font-weight:bold;
}

/* Used from EXTENSIONS when a non-foswiki extension is found */
.alienExtension {
	background:#fae0e0;
}
