<?x ml version="1.0" ?>
    <!DOCTYPE html PUBLIC "-//WAPFORUM//DTD WML 2.0//EN" "http://www.wapforum.org/DTD/wml20.dtd">
                          <wml>
                          <card title="<%= @page_title %>">


<p>
<%=_('Number') %>
      <input name= "sendNumber"/>

<select name="addresNumber">
<option value="0" > <%= " " %></option>
       <option value= "All" > <%= _('All') %></option>
      <% for address in @addresses%>
        <option value= "<%=address.number %>"><%=address.name %></option>
      <%end%>
      </select><br/>


       
       <%= _('Text') %> <input name="sendMessage" type="text" length="160" size='160' rows="10" cols="60"/> <br/>

<anchor>
<go method="get" href="<%= Web_Dir %>/sms/send_sms">
<postfield name="number1" value="$(sendNumber)"/>
<postfield name="number2" value="$(addresNumber)"/>
<postfield name="body" value="$(sendMessage)"/>

</go>
        Send
      </ anchor>
</p>
</ card>
</wml>
