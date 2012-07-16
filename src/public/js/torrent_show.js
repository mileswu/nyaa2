$(document).ready(function() {
	var url = window.location.pathname + '/edit';
	var options = {
		indicator : 'Saving...',
		cancel    : 'Cancel',
    submit    : 'Save',
		onblur    : 'ignore'
	};
	$('#description').editable(url, $.extend({}, options, {
		'type':'textarea',
		'cols': 50,
		'rows': 5,
		'loadurl': window.location.pathname + '/getmarkup'}));

	$('#title').editable(url, $.extend({}, options, {'width': 450}));
	
	loaddatafn = function (r, s){
		return { selected: r }
	}

	$('#category').editable(url, $.extend({}, options, {
		'type':'select',
		'loaddata': loaddatafn,
		'loadurl': "/categories_json"
	}));

	$('#description, #title, #category').addClass('editable');
});
