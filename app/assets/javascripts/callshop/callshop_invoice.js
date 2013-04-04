var cols = ["issue_date", "amount", "status", "comment", "user_type"];

function add_print() {
    $("a.print").live('click', function (ev) {
        ev.preventDefault();
        window.open($(this).attr('href'), "Invoice", "menubar=no,width=660,height=520,toolbar=no");
    });
}

function add_update(update_url) {
    $("input.update").live('click', function (ev) {
        ev.preventDefault();

        var row = $(this).closest('tr.slide').prev();
        var btn = row.find('a.edit');

        $.ajax({
            url:update_url,
            cache:false,
            type:'post',
            data:$(row).next().find('form').serialize(),
            beforeSend:function () {
                btn.addClass('loading');
            },
            success:function (data) {
                btn.removeClass('loading');
                $(row).next().remove();

                window.location.reload(true);
            }
        });
    });
}

function add_cancel() {
    $("input.cancel").live('click', function (ev) {
        $(this).closest("tr.slide").remove();
    });
}

function add_edit(invoice_edit_url) {
    $("a.edit").live('click', function (ev) {
        ev.preventDefault();
        var btn = $(this);
        var row = $(this).closest('tr.booth');

        if (row.next(".slide").length == 0) {
            $.ajax({
                url:invoice_edit_url,
                cache:false,
                data:'invoice_id=' + $(row).attr('id'),
                beforeSend:function () {
                    btn.removeClass('edit').addClass('preloader');
                },
                success:function (data) {
                    btn.removeClass('preloader').addClass('edit');
                    $(data).insertAfter(row);
                }
            });
        } else {
            row.next(".slide").remove();
        }
    });
}

function add_full_received() {
    $("#full_payment_received").live('click', function () {
        $("#pending_payment").attr('value', $("#invoice_total").val());
    });
}

function add_partial_received() {
    $("#partial_payment_received").live('click', function () {
        $("#pending_payment").attr('value', $("#invoice_current").val());
    });
}

function highlight_rows() {
    $("table tbody tr").each(function (row, el) {
        $(el).mouseover(function () {
            $(this).addClass('over');
        });

        $(el).mouseout(function () {
            $(this).removeClass('over');
        });
    });
}

function sortable_headers(context, invoice_list_url, invoice_print_url, invoice_edit_url) {
    $(context).find(".sort-col").live('click', function (ev) {
        ev.preventDefault();
        var el = $(this);
        var opts = { };

        el.parent().parent().children().each(function (i, child) {
            if ($(child)[0] != $(el.parent())[0]) {
                $(child).removeClass('sorted-on-asc sorted-on-desc');
            }
        });

        if (el.parent().hasClass('sorted-on-asc')) {
            el.parent().removeClass('sorted-on-asc').addClass('sorted-on-desc');
            opts = $.extend({
                reversed:true
            }, opts);
        } else {
            el.parent().removeClass('sorted-on-desc').addClass('sorted-on-asc');
        }

        $.ajax({
            url:invoice_list_url,
            cache:false,
            type:'GET',
            contentType: "application/json; charset=utf-8",
            data:{
                "order_by":el.attr('data-sort-type'),
                "order_dir":((opts["reversed"]) ? "DESC" : "ASC" )
            },
            beforeSend:function () {
                $('.booth, .slide').remove();
            },
            success:function (data) {
                update_invoices(data, invoice_print_url, invoice_edit_url);
            }
        });
    });
}

function pagination_links(context, invoice_list_url, invoice_print_url, invoice_edit_url) {
    $(context).find(".pagination_link").live('click', function (ev) {
        ev.preventDefault();
        var el = $(this);
        var page = el.attr("href").split("=", 2)[1];
        $.ajax({
            url:invoice_list_url,
            cache:false,
            type:'GET',
            contentType: "application/json; charset=utf-8",
            data:{
                "page":page
            },
            beforeSend:function () {
                $('.booth, .slide').remove();
            },
            success:function (data) {
                update_invoices(data, invoice_print_url, invoice_edit_url);
                update_pagination(data, invoice_list_url);
            }
        });
    });
}

function update_invoices(data, invoice_print_url, invoice_edit_url) {
    var hrow = "";
    var row;
    var x;
    var invoices = JSON.parse(data)["invoices"];
    for (var i = 0; i < invoices.length; i++) {
        row = invoices[i];
        hrow = "";
        for (var z = 0; z < cols.length; z++) {
            x = (row[cols[z]] == null) ? "" : row[cols[z]];
            hrow = hrow + "<td class='" + cols[z] + "'>" + x + "</td>\n";
        }
        hrow += "<td><a class='print' href='" + invoice_print_url + "?invoice_id=" + row["id"] + "'>&nbsp;</a></td>";
        hrow += "<td><div class='btn'><a class='edit' href='" + invoice_edit_url + "?invoice_id=" + row["id"] + "'>&nbsp;</a></div></td>";
        $('#invoices_list').append("<tr id='" + row["id"] + "' class='booth'>" + hrow + "</tr>");
    }
    highlight_rows();
}

function update_pagination(data, invoice_list_url) {
    $('.page_select').html("");
    var pages = data["pages"];
    var page;
    for (var z = 0; z < pages.length; z++) {
        page = pages[z];
        if (page[1] != null) {
            $('.page_select').append("<a class='pagination_link' href='" + invoice_list_url + "?page=" + page[1] + "'>" + page[0] + "</a>");
        } else {
            $('.page_select').append("<span class='current'>" + page[0] + "</span>");
        }
    }
}