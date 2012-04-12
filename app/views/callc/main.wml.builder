<?x ml version="1.0" ?>
    <!DOCTYPE html PUBLIC "-//WAPFORUM//DTD WML 2.0//EN" "http://www.wapforum.org/DTD/wml20.dtd">
                          <wml>
                          <card title="<%= @page_title %>">


<p>
<%= _('hello') %>, <%= @username %>
</p>
       
    <p>
          <%= @notice%>
    </ p>
<p>

<anchor>
<go method="get" href="<%= Web_Dir %>/sms/sms"></go>
        <%= _('Send_sms') %>
      </ anchor>
<anchor>
<go method="get" href="<%= Web_Dir %>/callc/logout"></go>
        <%= _('logout') %>
      </ anchor>
</p>
</ card>
</wml>