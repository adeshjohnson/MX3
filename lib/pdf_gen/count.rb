module PdfGen
  module Count
    def Count.page_number(pdf, page, pages)
      pdf.text("#{page}/#{pages}", {:top => 780, :alignment => :right, :font_size => 9})
      pdf
    end
=begin rdoc
# Counts total pages for units when first and the rest of the pages have different sizes.
#
# *Params*
#
# +units+ - number of items you want to display.
# +units_in_first_page+ - number of items that fit in the first page.
# +units_in_second_page+ - number of units that fit in the subsequent pages.
#
# *Returns*
#
# Integer number of total pages.
=end

    def Count.pages(units, units_in_first_page, units_in_second_page = nil)
      if units <= units_in_first_page
        return 1
      else
        if units_in_second_page.to_i > 0
          units -= units_in_first_page
          pages = units/units_in_second_page
          if units%units_in_second_page == 0
            return pages + 1
          else
            return pages + 2
          end
        else
          pages = units/units_in_first_page
          if units%units_in_first_page == 0
            return pages + 0
          else
            return pages + 1
          end
        end
      end
    end

    def Count.check_page_number(page, limit)
      page = page+1
      if page.to_i > limit.to_i
        raise PdfGen::PDFInvoiceLimitError.new("PDF invoice reach limit: #{limit}")
      else
        page
      end
    end

    def Count.error_message_from_limit(pdf, limit, user, invoice)
      Action.add_action_hash(user, {:target_id=>invoice.id, :target_type=>"Invoice", :action=>"Invoice_limit_reach", :data=>invoice.user_id})
      pdf.start_new_page
      pdf.text( _('Invoice_reach_limit') + ': ' + limit.to_s, {:left => 50, :top => 100, :font_size =>16})
      pdf.text( _('Invoice_reach_limit_contact_administrator'), {:left => 50, :top => 130, :font_size =>16})
      pdf
    end

  end
  # In case of pdf limit errror
  class PDFInvoiceLimitError < StandardError
  end

end
