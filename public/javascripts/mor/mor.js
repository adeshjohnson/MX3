var mor_functions = {
  "showAJAXLoader" : function(){ // Shows spinner
    $j("#spinner").show();
  }, 
  "hideAJAXLoader" : function(){ // Hides spinner
    $j("#spinner").hide();
  }, 
  "log" : function(msg){ // Writes message to firefox/chrome console.
    if(typeof(console) !== 'undefined' && console != null) {
      console.log(msg);
    }
  },
  "populateSelect" : function(path, target, defaul){
    var options = [];
    $j.ajax({
      url : path,
      complete : mor_functions["hideAJAXLoader"],
      beforeSend : function(){
        target.unbind("click");
        mor_functions["showAJAXLoader"]();

      },
      success : function(data, textStatus, XMLHttpRequest){
        $j.each(data, function(key, value){
          var obj = "<option value='"+value[0]+"'"
          if(defaul == value[0]){
            obj += "selected='selected'";
          }
          obj += ">"+value[1]+"</option>"
          options.push(obj);
        });

        target.html(options.join(""));
      },
      error : function(data, textStatus, XMLHttpRequest){
      },
      dataType : "json"
    });
  }
}

//alias to function
function log(msg){
  mor_functions["log"](msg);
}

function show_hide_menus(){
  var value = $j.cookie("hide_menus");
  if(value == "hide"){
    $j.cookie("hide_menus", "show", {
      path: '/'
    });
  } else {
    $j.cookie("hide_menus", "hide", {
      path: '/'
    });
  };
  read_show_hide_menus();
}

function show_hide_menus2(value){
  if(value == "0"){
    $j.cookie("hide_menus", "show", {
      path: '/'
    });
  } else {
    $j.cookie("hide_menus", "hide", {
      path: '/'
    });
  };
  read_show_hide_menus();
}

function read_show_hide_menus(){
  var value = $j.cookie("hide_menus");
  if(value == "hide"){
    $j(".application_side_expand").show();
    $j(".application_side_contract").hide();
    
    $j(".left_menu").hide();
    $j("#page_header").hide();
    $j("#left_menu_spacer").hide();
    $j(".header_spacer").hide();
  } else {
    $j(".application_side_expand").hide();
    $j(".application_side_contract").show();

    $j(".left_menu").show();
    $j("#page_header").show();
    $j("#left_menu_spacer").show();
    $j(".header_spacer").show();
  };
}