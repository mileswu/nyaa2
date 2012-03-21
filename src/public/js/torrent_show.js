$(document).ready(function() {
	var url = window.location.pathname + '/edit';
	var options = {
		indicator : 'Saving...',
		cancel    : 'Cancel',
    submit    : 'Save',
		onblur    : 'ignore'
	};
	var empty = {}
	$('#description').editable(url, $.extend(empty, options, {'type':'textarea', 'cols': 50, 'rows': 5}));
	var empty = {}
	$('#title').editable(url, $.extend(empty,options, {'width': 450}));
	
	
	loaddatafn = function (r, s){
		return { selected: r }
	}

	$('#category').editable(url, $.extend(options, {'type':'select',
		loaddata: loaddatafn,
		loadurl: "/categories_json"
	}));
});
