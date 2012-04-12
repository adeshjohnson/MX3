function update_totals() {
    $("#free_booths_count").html($("tr.booth.free").size());
    $("#active_calls_count").html($("tr.booth.occupied").size());
}

function log(message) {
    if (window.console) {
        console.debug(message);
    } else {
        alert(message);
    }
}

function remove_slide_menus(element) {
    $(element).next('tr.slide').remove();
}

(function ($) {
    var i18n;
    $.fn.callshop = function (options, i18ne) {
        i18n = i18ne;
        options = $.extend({
            id:null,
            free_booths:0,
            active_calls:0,
            refresh_interval:3000,
            refresh:true,
            cache:{
                booth_forms:{ }
            },
            urls:{
                'reservation':null,
                'termination':null,
                'termination_form':null,
                'reservation_form':null,
                'topup_form':null
            },
            updater:null,
            booths:null
        }, options);

        $(this).each(function () {

            /* register booths with data associate json data with html row */
            associateElements($(this));

            /* show new session reservation form when clicking 'start' */
            $(this).find("a.start-session").live('click', function (ev) {
                ev.preventDefault();

                callshop.show_reservation_form($(this).closest('.booth'));
            });

            /* hide new form if cancel is clicked */
            $(this).find("a.cancel").live('click', function (ev) {
                ev.preventDefault();
                var booth = elementToBooth($(this).closest('.booth'));

                switch (booth.state) {
                    case "reservation_form":
                        /* if we cancel 'from' reservation form state, booth stays free */
                        callshop.hide_form(booth.element, "free");
                        break;
                    case "summary":
                        if (booth.number != null) {
                            /* if we cancel from summary state and there is a call in progress booth stays occupied */
                            callshop.hide_form(booth.element, "occupied");
                        } else {
                            /* if we cancel from summary state and there are no calls in progress in this booth it stays in 'reserved' state */
                            callshop.hide_form(booth.element, "reserved");
                        }
                        break;
                    case "topup":
                        if (booth.number != null) {
                            /* if we cancel from topup state and there is a call in progress booth stays occupied */
                            callshop.hide_form(booth.element, "occupied");
                        } else {
                            /* if we cancel from topup state and there are no calls in progress in this booth it stays in 'reserved' state */
                            callshop.hide_form(booth.element, "reserved");
                        }
                        break;
                    case "comment_update":
                        if (booth.number != null) {
                            /* if we cancel from comment_form state and there is a call in progress booth stays occupied */
                            callshop.hide_form(booth.element, "occupied");
                        } else {
                            /* if we cancel from comment_form state and there are no calls in progress in this booth it stays in 'reserved' state */
                            callshop.hide_form(booth.element, "reserved");
                        }
                        break;
                }
                return false;
                /* omg this is magic! */
            });

            /*
             'cancel' button in reservation form functionality
             booth stays at free state
             */
            $(this).find("input.cancel").live('click', function () {
                var btn = $(this);

                $(this).jConfirmAction({
                    question:i18n.confirm.question,
                    yesAnswer:i18n.confirm.yes,
                    cancelAnswer:i18n.confirm.cancel,
                    callback:function () {
                        callshop.hide_form(btn.closest('tr.slide').prev(), "free");
                    }
                });
            });

            /* end session button */
            $("div.btn a.end-session").live('click', function (ev) {
                ev.preventDefault();
                var booth = elementToBooth($(this).closest('.booth'));

                /* if we end session of occupied booth we need to confirm wether the manager really wants to terminate the pending call */
                if (booth.state == "occupied") {
                    $(this).jConfirmAction({
                        question:i18n.confirm.question_terminated_calls,
                        yesAnswer:i18n.confirm.yes,
                        cancelAnswer:i18n.confirm.cancel,
                        callback:function () {
                            callshop.release_booth(booth.element);
                        }
                    });
                } else {
                    /* if booth has no pending calls, just release it */
                    callshop.release_booth(booth.element);
                }
            });


            /*
             end session and generate invoice' button in booth release form
             asks for user confirmation in order to proceed.
             */
            $(this).find("input.release_booth").live('click', function () {
                var booth = $(this);

                $(this).jConfirmAction({
                    question:i18n.confirm.question,
                    yesAnswer:i18n.confirm.yes,
                    cancelAnswer:i18n.confirm.cancel,
                    callback:function () {
                        callshop.close_booth(booth.closest('tr.slide').prev());
                    }
                });
            });

            /* reservation button in booth reservation form */
            $(this).find("input.reserve").live('click', function (ev) {
                ev.preventDefault();
                callshop.reserve_booth($(this).closest('tr.slide').prev());
            });

            /* button which when clicked shows balance topup form */
            $(this).find("a.topup-prepaid").live('click', function (ev) {
                ev.preventDefault();
                callshop.show_topup_form($(this).closest('.booth'));
            });

            /* comment edit form */
            $(this).find("a.comm-edit").live('click', function (ev) {
                ev.preventDefault();
                callshop.show_comment_update_form($(this).closest('.booth'));
            });

            /* comment update action button */
            $(this).find("input.comment-update").live('click', function (ev) {
                ev.preventDefault();

                var btn = $(this);
                var booth = elementToBooth($(this).closest("tr.slide").prev());
                var invoice = $("#invoice_id").attr('value');
                var comment = $("#invoice_comment").val();

                $.ajax({
                    url:options.urls.update,
                    postType:'json',
                    cache:false,
                    data:{
                        invoice_id:invoice,
                        "invoice[comment]":comment
                    },
                    beforeSend:function (x) {
                        callshop.change_state(booth, "loading", {});
                    },
                    success:function (data) {
                        $(booth.element).find(".comment").html(comment + ' <a href="" class="comm-edit" title="' + i18n.misc.update_comment + '" />');
                        if (booth.number != null) {
                            callshop.hide_form(booth.element, "occupied");
                        } else {
                            callshop.hide_form(booth.element, "reserved");
                        }
                    }
                });
            });

            /*
             balance addition/subtraction button
             if we choose to increase the balance we show relevant fields and vice versa.
             */
            $(this).find("input.increase").live('click', function (ev) {
                /* TODO prettify me */
                var slide = $(ev.currentTarget).parents(".slide");
                var increase = Math.ceil(parseFloat($(this).parents("table.invoice").find('input.balance').attr("value")) * 100) / 100;
                var currentAmount = parseFloat(elementToBooth($(this).parents("tr.slide").prev()).balance);
                var add_with_tax = 1; //$("input:checked").length;
                var invoice_tax_1 = parseFloat($("#invoice_tax_1").attr('value'));
                var invoice_tax_2 = parseFloat($("#invoice_tax_2").attr('value'));
                var invoice_tax_3 = parseFloat($("#invoice_tax_3").attr('value'));
                var invoice_tax_4 = parseFloat($("#invoice_tax_4").attr('value'));
                var compound_tax = $("#compound_tax").attr('value');
                var tax = increase
                if (isNaN(increase) || increase <= 0.0) {
                    slide.find(".decrease-balance").css("display", "none");
                    slide.find(".increase-balance").css("display", "none");
                    alert(i18n.validations.numerical_and_non_zero);
                } else {
                    if (add_with_tax == 1) {
                        if (compound_tax == 1) {
                            if (invoice_tax_4 > 0) {
                                tax = tax / (invoice_tax_4 + 100) * 100;
                            }
                            if (invoice_tax_3 > 0) {
                                tax = tax / (invoice_tax_3 + 100) * 100;
                            }
                            if (invoice_tax_2 > 0) {
                                tax = tax / (invoice_tax_2 + 100) * 100;
                            }
                            if (invoice_tax_1 > 0) {
                                tax = tax / (invoice_tax_1 + 100) * 100;
                            }
                        } else {
                            tax = tax / (((invoice_tax_1 + invoice_tax_2 + invoice_tax_3 + invoice_tax_4) / 100.0) + 1.0);
                        }
                        increase = Math.ceil(tax * 100) / 100;
                    }
                    slide.find(".increase-balance").find(".addition").html(increase);
                    slide.find(".increase-balance").find(".total").html(increase + currentAmount);
                    slide.find(".increase-balance").css("display", "inline");
                    slide.find(".decrease-balance").css("display", "none");
                }
            });

            /* subtract amount from balance */
            $(this).find("input.decrease").live('click', function (ev) {
                /* TODO prettify me */
                var slide = $(ev.currentTarget).parents(".slide");
                var decrease = Math.ceil(parseFloat($(this).parents("table.invoice").find('input.balance').attr("value")) * 100) / 100;
                var currentAmount = parseFloat(elementToBooth($(this).parents("tr.slide").prev()).balance);
                var add_with_tax = 1; //$("input:checked").length;
                var invoice_tax_1 = parseFloat($("#invoice_tax_1").attr('value'));
                var invoice_tax_2 = parseFloat($("#invoice_tax_2").attr('value'));
                var invoice_tax_3 = parseFloat($("#invoice_tax_3").attr('value'));
                var invoice_tax_4 = parseFloat($("#invoice_tax_4").attr('value'));
                var compound_tax = $("#compound_tax").attr('value');
                var tax = decrease

                if (isNaN(decrease) || decrease <= 0.0) {
                    slide.find(".decrease-balance").css("display", "none");
                    slide.find(".increase-balance").css("display", "none");
                    alert(i18n.validations.numerical_and_non_zero);
                } else {
                    if (add_with_tax == 1) {
                        if (compound_tax == 1) {
                            if (invoice_tax_4 > 0) {
                                tax = tax / (invoice_tax_4 + 100) * 100;
                            }
                            if (invoice_tax_3 > 0) {
                                tax = tax / (invoice_tax_3 + 100) * 100;
                            }
                            if (invoice_tax_2 > 0) {
                                tax = tax / (invoice_tax_2 + 100) * 100;
                            }
                            if (invoice_tax_1 > 0) {
                                tax = tax / (invoice_tax_1 + 100) * 100;
                            }
                        } else {
                            tax = tax / (((invoice_tax_1 + invoice_tax_2 + invoice_tax_3 + invoice_tax_4) / 100.0) + 1.0);
                        }
                        decrease = Math.ceil(tax * 100) / 100;
                    }
                    slide.find(".decrease-balance").find(".addition").html(decrease);
                    slide.find(".decrease-balance").find(".total").html((currentAmount - decrease <= 0) ? 0 : currentAmount - decrease);
                    slide.find(".decrease-balance").css("display", "inline");
                    slide.find(".increase-balance").css("display", "none");
                }
            });

            /*
             adjust balance button, which sends ajax request which increases or decreases user's/booth's balance
             */
            $(this).find("input.adjust-balance").live('click', function (ev) {
                var btn = $(this);
                var booth = elementToBooth($(this).closest("tr.slide").prev());
                var invoice = $("#invoice_id").attr('value');
                var adjustment = Math.ceil(parseFloat($(this).parents("table.invoice").find('input.balance').attr("value")) * 100) / 100;
                var add_with_tax = 1; //$("input:checked").length;
                $.ajax({
                    url:options.urls.top_up,
                    postType:'json',
                    cache:false,
                    data:{
                        invoice_id:invoice, /* invoice id which balance we are adjusting */
                        /* if we increase the amount (increase element is visible) we need to increase original amount because AJAX updater returns original invoice balance minus call price */
                        "invoice[balance]":parseFloat(adjustment),
                        /* indicator that we are increasing or not */
                        add_with_tax:add_with_tax,
                        increase:($(".increase-balance").css("display") == "inline")
                    },
                    beforeSend:function (x) {
                        callshop.change_state(booth, "loading", {});
                    },
                    success:function (data) {
                        if (booth.number != null) {
                            callshop.hide_form(booth.element, "occupied");
                        } else {
                            callshop.hide_form(booth.element, "reserved");
                        }
                    }
                });
            });

            /*
             relevant only to Rails development environment
             toggles ajax upadting of booth status
             */
            $("#toggle-updating a").click(function (ev) {
                ev.preventDefault();
                if ($(this).hasClass('running')) {
                    $(this).removeClass('running').addClass('not-running');
                    options.refresh = false;
                } else {
                    $(this).removeClass('not-running').addClass('running');
                    options.refresh = true;
                }
            });

            /*
             column sorting
             */
            $(this).find(".sort-col").live('click', function (ev) {
                ev.preventDefault();
                var el = $(this);
                var opts = { };

                /* first we remove previous sort indications */
                el.parent().parent().children().each(function (i, child) {
                    if ($(child)[0] != $(el.parent())[0]) {
                        $(child).removeClass('sorted-on-asc sorted-on-desc');
                    }
                });

                /* if current element is already sorted we do reverse-sort */
                if (el.parent().hasClass('sorted-on-asc')) {
                    el.parent().removeClass('sorted-on-asc').addClass('sorted-on-desc');
                    opts = $.extend({
                        reversed:true
                    }, opts);
                } else {
                    el.parent().removeClass('sorted-on-desc').addClass('sorted-on-asc');
                }

                /* javascript reordering of DOM elements */
                $("#callshop tbody").reorder("tr.booth", $.extend({
                    by:function (v) { /* sorting condition is text of a cell element */
                        return v.find("." + el.attr('data-sort-type')).text();
                    }
                }, opts));

                /* since sorting script recreates elements we need to associate them with options object */
                associateElements($("#callshop"));
            });

            // periodic updater
            options.updater = $.periodic({
                period:options.refresh_interval,
                decay:1,
                max_period:10000
            }, function () {
                if (options.refresh) {
                    $.ajax({
                        url:options.urls.status_url_v2,
                        dataType:'json',
                        success:function (result) {
                            if (result != null) {
                                // update numbers


                                $.each(result.booths, function (i, current) {
                                    $.each(options.booths, function (j, booth) {
                                        if (current.id == booth.id) {
                                            // update booth only if we received new information (timestamp comparison)
                                            if ((current.timestamp != booth.timestamp) || (current.balance != booth.balance)) {
                                                var row = $("tr#booth-" + current.id);
                                                $.each(current, function (key, value) {
                                                    // bulk update all cells except specified ones, which are static
                                                    if (!key.match(/element|local_state|state/)) {
                                                        booth[key] = current[key];
                                                        row.find('.' + key).html((booth[key] == null) ? "-" : booth[key]);
                                                    }
                                                });

                                                // change booth to comment_updatestate
                                                callshop.change_state(booth, current.state, {
                                                    remove:false
                                                });

                                                // let user edit the booth comment
                                                if ((current.state.match(/occupied|reserved/)) && (row.find('.comment').find('a').length == 0)) {
                                                    row.find('.comment').append(' <a href="" class="comm-edit" title="' + i18n.misc.update_comment + '" />');
                                                }
                                                // if we determine that a booth got occupied or reserved by prepaid client, we need to inject balance adjustment link and colorize booth user type
                                                if (current.state.match(/occupied|reserved/)) {
                                                    var balance_col = row.find('.balance');
                                                    balance_col.html(sprintf("%.2f", parseFloat(balance_col.html())));
                                                    if (current.user_type.match(/postpaid/)) {
                                                        balance_col.prepend(i18n.user_types.postpaid.toUpperCase() + " (").append(")").wrapInner(function () {
                                                            var val = parseFloat(current.balance);
                                                            return (val == 0.0) ? "<span class='balance-value green' />" : "<span class='balance-value red' />";
                                                        });
                                                    } else {
                                                        balance_col.prepend(i18n.user_types.prepaid.toUpperCase() + " (").append(")").append(
                                                            $("<a href='' class='prepaid topup topup-prepaid' title='" + i18n.adjust_user_balance + "'>&nbsp;</a>")
                                                        ).wrapInner(function () {
                                                                var val = parseFloat(current.balance);
                                                                return (val < 0.0) ? "<span class='balance-value red' />" : "<span class='balance-value green' />";
                                                            });
                                                    }
                                                }
                                            }

                                            //Update just call Duration
                                            if (((current.timestamp != booth.timestamp) || (current.balance != booth.balance) || (current.duration != booth.duration) )) {
                                                var a_row = $("tr#booth-" + current.id);
                                                booth["duration"] = current["duration"];
                                                a_row.find('.duration').html((booth["duration"] == null) ? "-" : booth["duration"]);
                                            }
                                        }
                                    });
                                });
                                update_totals();
                            }
                        }
                    });
                }
            });

        });

        var callshop = {

            /**
             * shows new reservation form which is fetched using ajax and then cached
             * for speedy later use
             */

            show_reservation_form:function (a_booth) {
                var booth = elementToBooth(a_booth);

                if (booth.state != "reservation_form") {

                    if (booth.element.id in options.cache.booth_forms) {
                        $(options.cache.booth_forms[booth.element.id]).insertAfter($(booth.element)).show();
                        callshop.change_state(booth, "reservation_form", {});
                    } else {
                        $.ajax({
                            url:options.urls.reservation_form,
                            data:'user_id=' + booth.id,
                            beforeSend:function () {
                                callshop.change_state(booth, "loading", {});
                            },
                            success:function (data) {
                                callshop.change_state(booth, "reservation_form", {});
                                var form = $(data).css('display', 'none');
                                /* hide ajax-fetched content at first */

                                var booth_cache = new Array();
                                booth_cache[booth.element.id] = data;

                                options.cache.booth_forms = $.extend(booth_cache, options.cache);

                                form.insertAfter($(booth.element)).show();
                                /* inject content and show it */
                            }
                        });
                    }

                    /* prepaid booth has amount field and postpaid does not */
                    $("#invoice_invoice_type_prepaid").live('click', function () {
                        $(this).nextAll(".balance").css("display", "inline");
                    });

                    $("#invoice_invoice_type_postpaid").live('click', function () {
                        $(this).nextAll(".balance").css("display", "none");
                    });
                }
            },

            /* hides active form and changes booth to specified state */
            hide_form:function (a_booth, state) {
                var booth = elementToBooth(a_booth);

                $(booth.element).nextUntil('tr.booth').each(function (i, el) {
                    $(el).remove();
                });
                this.change_state(booth, state, {});
            },

            /*
             form reservation action
             send invoice type and amount
             */
            reserve_booth:function (a_booth) {
                var booth = elementToBooth(a_booth);

                if ($("#invoice_balance").val() != "") {
                    $.ajax({
                        url:options.urls.reservation,
                        type:'post',
                        postType:'json',
                        cache:false,
                        data:$(booth.element).next().find('form').serialize(),
                        beforeSend:function (x) {
                            callshop.change_state(booth, "loading", {});
                        },
                        success:function (data) {
                            callshop.hide_form(booth.element, "reserved");
                        }
                    });
                } else {
                    alert(i18n.validations.numerical_and_non_zero);
                }
            },

            /*
             action, which sends ajax request to make the booth free (after being reserved or free)
             */
            close_booth:function (a_booth) {
                var booth = elementToBooth(a_booth);
                var comment = $("#invoice_comment")[0].value;
                var balance;
                var payment_received;
                /* if invoice type is 'postpaid'. we verify that by checking wether full_payment_received option is present */
                if ($("#full_payment_received").length > 0) {
                    balance = parseFloat($("#pending_payment")[0].value);
                    payment_received = $("#full_payment_received")[0].checked == true;
                } else {
                    balance = $("#invoice_total").val();
                    payment_received = true;
                }

                $.ajax({
                    url:options.urls.termination,
                    type:'post',
                    data:'user_id=' + booth.id + "&comment=" + comment + "&balance=" + balance + "&full_payment=" + payment_received,
                    beforeSend:function () {
                        callshop.change_state(booth, "loading", {});
                    },
                    success:function (data) {
                        callshop.hide_form(booth.element, "free");
                    }
                });
            },

            /*
             show summary of booth usage
             */
            release_booth:function (a_booth) {
                var booth = elementToBooth(a_booth);

                if (booth.state != "topup") { /* do not open more than two forms for one booth */
                    $.ajax({
                        url:options.urls.termination_form,
                        data:'user_id=' + booth.id + "&server=" + booth.server + "&channel=" + booth.channel,
                        beforeSend:function () {
                            callshop.change_state(booth, "loading", {});
                        },
                        success:function (data) {
                            callshop.change_state(booth, "summary", {});
                            remove_slide_menus($(booth.element));
                            $(data).insertAfter($(booth.element));
                        }
                    });
                }
            },

            show_comment_update_form:function (a_booth) {
                var booth = elementToBooth(a_booth);

                if (booth.state != "comment_update") {
                    $.ajax({
                        url:options.urls.comment_update,
                        data:'user_id=' + booth.id,
                        beforeSend:function () {
                            callshop.change_state(booth, "loading", {});
                        },
                        success:function (data) {
                            clear_booth_slide(callshop, booth);
                            callshop.change_state(booth, "comment_update", {});
                            $(data).insertAfter($(booth.element));
                        }
                    });
                } else {
                    clear_booth_slide(callshop, booth);
                }
            },

            /*
             balance topup form . show only if summary is not shown
             */
            show_topup_form:function (a_booth) {
                var booth = elementToBooth(a_booth);

                if (!booth.local_state && booth.state != "summary") { /* dirty */
                    $.ajax({
                        url:options.urls.topup_form,
                        data:'user_id=' + booth.id,
                        beforeSend:function () {
                            callshop.change_state(booth, "loading", {});
                        },
                        success:function (data) {
                            clear_booth_slide(callshop, booth);
                            callshop.change_state(booth, "topup", {});
                            $(data).insertAfter($(booth.element));
                        }
                    });
                } else {
                    clear_booth_slide(callshop, booth);
                }
            },

            /* change booth state to specified one */
            change_state:function (booth, state, options) {
                var settings = {
                    remove:true
                };
                $.extend(settings, options);
                var button = $(booth.element).find('div.btn a');
                var row = $(booth.element);
                var has_cancel = button.hasClass("cancel");

                button.removeClass('start-session preloader end-session cancel');

                booth.state = state;

                switch (booth.state) {
                    case "loading":
                        button.html('&nbsp;').addClass('preloader');
                        break;
                    case "free":
                        button.html('Start').addClass('start-session');
                        booth.local_state = false;
                        row.find('.balance-value').removeClass('postpaid prepaid');
                        /* balance */
                        row.find('.balance').find('a').remove();
                        /* balance */
                        $(booth.element).removeClass('reserved occupied').addClass('free');
                        break;
                    case "reservation_form":
                        booth.local_state = true;
                        button.html(i18n.states.cancel).addClass('cancel');
                        break;
                    case "reserved":
                        button.html(i18n.states.end).addClass('end-session');
                        booth.state = "reserved";
                        booth.local_state = false;
                        $(booth.element).removeClass('free occupied').addClass('reserved');
                        if (settings["remove"] == true) {
                            $(booth.element).next('tr.slide').remove();
                        }
                        break;
                    case "summary":
                        button.html(i18n.states.cancel).addClass('cancel');

                        $("#full_payment_received").live('click', function () {
                            $("#pending_payment").val(sprintf("%.2f", parseFloat($("#invoice_total").val())));
                            $('#pending_payment').trigger('change');
                        });

                        $("#partial_payment_received").live('click', function () {
                            $("#pending_payment").val(sprintf("%.2f", parseFloat($("#invoice_current").val())));
                            $('#pending_payment').trigger('change');
                        });

                        $("#pending_payment").live('change', function () {
                            $("#money_return").html(sprintf("%.2f", parseFloat($("#pending_payment").val()) - parseFloat($("#invoice_total").val())) + " " + options.currency);
                        });

                        break;
                    case "topup":
                        booth.local_state = true;
                        button.html(i18n.states.cancel).addClass('cancel');
                        break;
                    case "occupied":
                        $(booth.element).removeClass('reserved free').addClass('occupied');
                        if (has_cancel == true) {
                            button.html(i18n.states.cancel).addClass('cancel');
                        } else {
                            button.html(i18n.states.end).addClass('end-session');
                        }

                        if (settings["remove"] == true) {
                            $(booth.element).next('tr.slide').remove();
                        }

                        booth.state = "occupied";
                        booth.local_state = false;
                        break;
                    case "comment_update":
                        booth.local_state = true;
                        button.html(i18n.states.cancel).addClass('cancel');
                        break;
                }
                ;
            }

        };

        function clear_booth_slide(callshop, booth) {
            if (booth.number != null) {
                callshop.hide_form(booth.element, "occupied");
            } else {
                callshop.hide_form(booth.element, "reserved");
            }
        }

        function log(message) {
            if (window.console) {
                console.debug(message);
            } else {
                alert(message);
            }
        }

        /* associates javascript objects with booth html elements */
        function associateElements(callshop) {
            callshop.find('.booth').each(function (i, el) {
                $.map(options.booths, function (booth) {
                    if (booth.id == boothId(el)) {
                        booth.element = el;
                    }
                });
            });
        }

        function elementToBooth(el) {
            return $.grep(options.booths, function (booth) {
                if (booth.id == boothId(el)) {
                    return booth
                } else {
                    return null;
                }
            })[0];
            return null;
        }

        function boothId(el) {
            return $(el).attr('id').match(/booth-(\d+)/)[1];
        }
    }
})(jQuery);