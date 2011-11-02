// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults
jQuery(function ($) {
  $.fn.extend({
    turnRemoteToToggle: function(target,altText){
        var $el = $(this),
            altText = altText || "Hide";

        $el.text(altText);
        $el.toggle(
          function(){
            $el.text(el.data('origText'));
            $el.data('expanded', false);
            target.slideUp(); // or target.hide() or other effect
          }, 
          function(){
            $el.text(altText);
            $el.data('expanded', true);
            target.slideDown(); // or target.show() or whatever
          }
        );
      }
  });
});

jQuery(document).ready(function() {
  jQuery('form[data-remote]').bind("ajax:before", function(){
    for (instance in CKEDITOR.instances){
      CKEDITOR.instances[instance].updateElement();
    }
  });

  // this gives an error about $clicked.attr() not being a function
  //jQuery('a[data-remote]').live("ajax:beforeSend", function(){
  //  var $clicked = $(this);
  //  $disable_with = $clicked.attr("data-disable-with");
  //  $loader_name = $clicked.attr("data-loader-name");
  //  $clicked.replaceWith($disable_with+' <img src=\"/images/ajax/'+$loader_name+'.gif\">');
  //  // $clicked.href("#");
  //});

	var isChrome = /Chrome/.test(navigator.userAgent);
	if(!isChrome & jQuery.support.opacity) {
		//jQuery(".tab_header a, div.tab_body").corners(); 
	}
	//jQuery("#priority_column, #intro, #buzz_box, #content_text, #notification_show, .bulletin_form").corners();
	//jQuery("#top_right_column, #toolbar").corners("bottom");
	
	jQuery("abbr[class*=timeago]").timeago();	
	jQuery("#pointContent").NobleCount('#pointContentDown',{ on_negative: 'go_red', on_positive: 'go_green', max_chars: 500 });
	jQuery("input#priority_name, input#change_new_priority_name, input#point_other_priority_name, input#revision_other_priority_name, input#right_priority_box").autocomplete("/priorities.js");
	jQuery("input#user_login_search, input#government_official_user_name").autocomplete("/users.js");
	jQuery('#bulletin_content, #blurb_content, #message_content, #document_content, #email_template_content, #page_content').autoResize({extraSpace : 20})
	
	function addMega(){ 
	  jQuery(this).addClass("hovering"); 
	} 

	function removeMega(){ 
	  jQuery(this).removeClass("hovering"); 
	}
	var megaConfig = {
	     interval: 20,
	     sensitivity: 1,
	     over: addMega,
	     timeout: 20,
	     out: removeMega
	};
	jQuery(".mega").hoverIntent(megaConfig);

	jQuery('a#login_link').click(function() {
	  jQuery('#login_form').show('fast');
	  return false;
	});
});

function toggleAll(name)
{
  boxes = document.getElementsByClassName(name);
  for (i = 0; i < boxes.length; i++)
    if (!boxes[i].disabled)
   		{	boxes[i].checked = !boxes[i].checked ; }
}

function setAll(name,state)
{
  boxes = document.getElementsByClassName(name);
  for (i = 0; i < boxes.length; i++)
    if (!boxes[i].disabled)
   		{	boxes[i].checked = state ; }
}
