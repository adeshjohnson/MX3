function observe_field_for_number(field){
  var notIntRegex = /[\D\+]+/g;
  field.bind("change keyup", function() {
    var obj = $(this);
    var old_value =  obj.val();
    var value = old_value.replace(notIntRegex, '');
    
    if(value != old_value){
      obj.val(value);
      obj.effect("highlight", {
        "color" : "#ff0000"
      }, 400);
    }
  });
}

function show_ajax_start(){
  $("#number_results").html("");
  $(".ajax_loader").show();
}

function show_ajax_end(){
  $(".ajax_loader").hide();
}

function update_number_info(json){
  var table = $("<ul></ul>");
  $.each(json, function(index, element){
     var name = element["name"];
     var value = element["value"];
     if(element["type"] == "with_flag"){
       flag = $("<img src='" + number_info["url"]["prefix"] + "/images/flags/"+element["flag"]+".jpg'>");
       value = $('<div/>').append(flag.clone()).html() + "&nbsp;"+ value;
     }
     table.append($("<li></li>").append(name).append(":&nbsp;").append(value));
  })
//  flag = $("<img src='" + number_info["url"]["prefix"] + "/images/flags/"+json["flag"].toLowerCase()+".jpg'>&nbsp;");
//  table.append($("<li></li>").append(flag).append(json["result"]));
//  table.append($("<li></li>").html(json));
  $("#number_results").html("");
  $("#number_results").append(table);
}

function remote_update_number_info(){
  var number = $("#number_input").val();
  if((number) && (number > 0)){
    show_ajax_start();
    $.ajax({
      url: number_info["url"]["number_info_path"],
      data: {
        "number" : number
      },
      method: "GET",
      dataType: 'json',
      success: update_number_info,
      complete: show_ajax_end
    })
  } else {
    $("#number_results").html(number_info["i18n"]["enter_number"]);
  }
}

function remove_ready_number_menu(event){
  $(".darkenBackground").remove();
  $("#number_information").remove();
}

function bind_ready_number(){
  $("li#number a").click(function(event){
    event.preventDefault();
    var dark = $("<div class='darkenBackground'></div>");
    var number_input = $("<input type='text' name='number' id='number_input' size='30'>");
    var close = $("<div class='close_button'></div>");
    var ok_button = $("<div class='button submit'><span class='img'></span>" + number_info["i18n"]["button_ok"] + "</div>")
    var cancel_button = $("<div class='button cancel'><span class='img'></span>" + number_info["i18n"]["button_cancel"] +"</div>")
    var form = $("<form><label for='number_input'>" + number_info["i18n"]["number"] +": </label></form>");
    var frame = $("<div id='number_information' class='number_information'></div>");
    var buttons = $("<div class='button_bar'></div>");
    var data = $("<div class='ajax_loader'></div><div id='number_results'></div>");

    observe_field_for_number(number_input);

    dark.click(remove_ready_number_menu);
    close.click(remove_ready_number_menu);
    cancel_button.click(remove_ready_number_menu);
    ok_button.click(remote_update_number_info);
    dark.appendTo("body");

    buttons.append(ok_button);
    buttons.append(cancel_button);
    form.append(number_input);
    form.append(data);
    form.append(buttons);

    frame.append(close);
    frame.append(form);

    frame.appendTo("body");
    return false;
  });
};

$(document).ready(bind_ready_number);