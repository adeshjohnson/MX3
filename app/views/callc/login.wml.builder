<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//WAPFORUM//DTD WML 2.0//EN" "http://www.wapforum.org/DTD/wml20.dtd">
<wml>
<card title="<%= @page_title %>">


    <p>
      <%= _('enter_username_and_psw') %> :
    </p>
    <p>
      <input name="sendUsername" type="text"/>
     <br/>
     <input name="sendPassword" type="text"/>
     <br/>   
       <anchor>
        <go method="get" href="<%= Web_Dir %>/callc/try_to_login">
          <postfield name="login[username]" value="$(sendUsername)"/>
          <postfield name="login[psw]" value="$(sendPassword)"/>          
        </go>
        <%= _('login') %>
      </anchor>
    </p>
</card>
</wml>
