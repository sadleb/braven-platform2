// requires jquery
// requires jquery-ui

// This is a part of Braven Network.
// Please don't add features to Braven Network.
// This code should be considered unsupported. We want to remove it ASAP.

$(document).ready(function($) {
	// Generate multiple-autocomplete input:
	function split( val ) {
		return val.split( /,\s*/ );
	}
	function extractLast( term ) {
		return split( term ).pop();
	}

	$('.multi-complete').each(function(){
		var availableTags = JSON.parse(this.dataset.multiCompleteOptions);
		$(this)
			// don't navigate away from the field on tab when selecting an item
			.on( "keydown", function( event ) {
				if ( event.keyCode === $.ui.keyCode.TAB && this.isOpenedByUser ) {
					event.preventDefault();
				}
			})
			.autocomplete({
				minLength: 0,
				source: function( request, response ) {
					// delegate back to autocomplete, but extract the last term
					response( $.ui.autocomplete.filter( availableTags, extractLast( request.term ) ) );
				},
				focus: function() {
					// prevent value inserted on focus
					return false;
				},
				open: function( event, ui ) {
                                  this.isOpenedByUser = true;
                                },
				close: function( event, ui ) {
                                  this.isOpenedByUser = false;
                                },
				select: function( event, ui ) {
					var terms = split( this.value );
					// remove the current input
					terms.pop();
					// add the selected item
					terms.push( ui.item.value );
					// add placeholder to get the comma-and-space at the end
					terms.push( "" );
					this.value = terms.join( ", " );
					return false;
				}
		});
	});

	$('form#request-contact-form').on('submit', function(event) {
		var ele = this.querySelectorAll('input[type=checkbox]');
		var checked = 0;
		var maxAllowed = this.dataset.maxAllowed;
		for(var i = 0; i < ele.length; i++)
			if(ele[i].checked)
				checked += 1;
		if(checked == 0) {
			alert('To contact a member, first click their name and see their LinkedIn profile. Then, come back to this tab and check the box that will appear next to their name.');
			return false;
		}
		if(checked > maxAllowed) {
			alert('You can only contact up to two members of the Braven Network at a time. This includes active contacts you have already reached out to but have not filled out the survery for. Please unselect any more than that.');
			return false;
		}
		return true;
	});
});
