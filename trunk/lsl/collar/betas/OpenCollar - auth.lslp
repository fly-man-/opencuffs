//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

//save owner, secowners, and group key
//check credentials when messages come in on COMMAND_NOAUTH, send out message on appropriate channel
//reset self on owner change

key wearer;
key owner;
string ownername;
key group = NULL_KEY;
string groupname;
integer groupenabled = FALSE;
list secowners;//strided list in the form key,name
list blacklist;//list of blacklisted UUID
string tmpname; //used temporarily to store new owner or secowner name while retrieving key
integer notified = FALSE;
string  wikiURL = "http://code.google.com/p/opencollar/wiki/UserDocumentation";
string parentmenu = "Main";
string submenu = "Owners";

string requesttype; //may be "owner" or "secowner" or "rem secowner"
key httpid;
key ownerOnlineCheck;

integer page = 0;
integer listenchannel = 802930;//just something i randomly chose
integer listener;
integer timeout = 60;
//added for attachment auth
integer interfaceChannel = -12587429;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;//deprecated
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;  // new for safeword
integer COMMAND_BLACKLIST = 520;
//added for attachment auth (garvin)
integer ATTACHMENT_REQUEST = 600;
integer ATTACHMENT_RESPONSE = 601;

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.

integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim

//string UPMENU = "?";
//string MORE = "?";
string UPMENU = "^";
string MORE = ">";

string setowner = "Set Owner";
string setsecowner = "Add Secowner";
string setblacklist = "Add Blacklisted";
string setgroup = "Set Group";
string reset = "Reset All";
string remsecowner = "Rem Secowner";
string remblacklist = "Rem Blacklisted";
string unsetgroup = "Unset Group";
string listowners = "List Owners";
string setopenaccess = "SetOpenAccess";
string unsetopenaccess = "UnsetOpenAccess";
integer openaccess; // 0: disabled, 1: openaccess

integer remenu = FALSE;

Notify(key id, string msg, integer alsoNotifyWearer) {
    if (id == wearer) {
        llOwnerSay(msg);
    } else {
        llInstantMessage(id,msg);
        if (alsoNotifyWearer) {
            llOwnerSay(msg);
        }
    }    
}
SetOwner(key id)
{   //moved to a function as it can be called now from either the sensor or http event
    if (requesttype == "owner")
    {
        owner = id;
        ownername = tmpname;
        //send wearer a message about the new ownership
        Popup(wearer,"You are now owned by " + ownername + ".");
        //owner might be offline, so they won't necessarily get a popup.  Send an IM instead
        Notify(owner, "You have been set as owner on " + llKey2Name(wearer) + "'s collar.\nFor help concerning the collar usage either say \"*help\" in chat or go to " + wikiURL +" .",FALSE);
        //save owner to httpdb in form key,name
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, "owner=" + (string)owner + "," + ownername, NULL_KEY);
        //added for attachment interface to announce owners have changed
        llWhisper(interfaceChannel, "CollarCommand|499|OwnerChange");
    }
    else if (requesttype == "secowner")
    {   //only add to list if this secowner not already there
        key secowner = id;                
        integer index = llListFindList(secowners, [(string)id]);
        if (index == -1)
        {   //secowner is not already in list.  add him/her
            secowners += [(string)id, tmpname];
        }
        else
        {   //secowner is already in list.  just replace the name
            secowners = llListReplaceList(secowners, [tmpname], index + 1, index + 1);
        }
        
        if (secowner != wearer)
        {
            Popup(wearer, "Added secondary owner " + tmpname);
        }
        Notify(secowner, "You have been added you as a secondary owner to " + llKey2Name(wearer) + "'s collar.\nFor help concerning the collar usage either say \"*help\" in chat or go to " + wikiURL + " .",FALSE);
        //save secowner list to database
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, "secowners=" + llDumpList2String(secowners, ","), NULL_KEY);
        //added for attachment interface to announce owners have changed
        llWhisper(interfaceChannel, "CollarCommand|499|OwnerChange");
    }    
    else if (requesttype == "blacklist")
    {   //only add to list if not already blacklisted
        key blacklisted = id;                
        integer index = llListFindList(blacklist, [(string)id]);
        if (index == -1)
        {   //blacklisted is not already in list.  add him/her
            blacklist += [(string)id, tmpname];
        }
        else
        {   //blacklisted is already in list.  just replace the name
            blacklist = llListReplaceList(blacklist, [tmpname], index + 1, index + 1);
        }
        
        if (blacklisted != wearer)
        {
            Popup(wearer, "Added to black list: " + tmpname);
        }
        //save secowner list to database
        llMessageLinked(LINK_THIS, HTTPDB_SAVE, "blacklist=" + llDumpList2String(blacklist, ","), NULL_KEY);
    }    
}

debug(string str)
{
    //llOwnerSay(llGetScriptName() + ": " + str);
}

integer SecOwnerExists(string name)
{
    
    return (~llSubStringIndex(llToLower(llDumpList2String(secowners, ",")), llToLower(name)));
}
integer BlackListExists(string name)
{
    
    return (~llSubStringIndex(llToLower(llDumpList2String(blacklist, ",")), llToLower(name)));
}

Popup(key id, string message)
{   //one-way popup message.  don't listen for these anywhere
    llDialog(id, message, [], 298479);
}

Name2Key(string formattedname)
{   //formatted name is firstname+lastname
    httpid = llHTTPRequest("http://w-hat.com/name2key?terse=1&name=" + formattedname, [HTTP_METHOD, "GET"], "");
}

GetGroupName(key groupkey)
{
    httpid = llHTTPRequest("http://groupname.scriptacademy.org/" + (string)groupkey, [HTTP_METHOD, "GET"], "");
}

AuthMenu(key av)
{
    string prompt = "Pick an option.";
    prompt += "  (Menu will time out in " + (string)timeout + " seconds.)\n";    
    list buttons;
    //add owner
    buttons += [setowner];    
    //add secowner
    buttons += [setsecowner];
    //blacklist someone
    buttons += [setblacklist];
    //set group    
    if (group==NULL_KEY) buttons += [setgroup];
    //unset group
    else buttons += [unsetgroup];
    //set open access
    if (!openaccess) buttons += [setopenaccess];
    //unset open access
    else buttons += [unsetopenaccess];
    //reset
    buttons += [reset];     
    //rem secowner    
    buttons += [remsecowner];    
    //rem blacklisted    
    buttons += [remblacklist];    
    //list owners
    buttons += [listowners];   
     //parent menu
    buttons += [UPMENU];
    llListenRemove(listener);
    listener = llListen(listenchannel, "", av, "");
    buttons = RestackMenu(buttons);
    llDialog(av, prompt, buttons, listenchannel);    
    llSetTimerEvent((float)timeout);    
}

RemSecOwnerMenu(key id)
{   //create a list
    list buttons;
    string prompt = "Choose which SecOwner to remove. (This menu will expire in 45 seconds.)\n";
    //build a button list with the dances, and "More"
    //get number of secowners
    integer num_secowners = llGetListLength(secowners);
    integer n;
    for (n=1; n <= num_secowners/2; n = n + 1)
    {
        string name = llList2String(secowners, 2*n-1);
        if (name != "")
        {
          prompt += "\n" + (string)(n) + " - " + name;
          buttons += [(string)(n)];
         }
    }  
    buttons += [UPMENU, "Remove All"];
    buttons = RestackMenu(buttons);
    requesttype = "rem secowner"; 
    listener = llListen(listenchannel, "", id, "");
    llDialog(id, prompt, buttons, listenchannel);
    //the menu needs to time out
    llSetTimerEvent(45.0);
}
RemBlackListMenu(key id)
{   //create a list
    list buttons;
    string prompt = "Choose which BlackListed to remove. (This menu will expire in 45 seconds.)\n";
    //get number of blacklisted
    integer num_blacklisted = llGetListLength(blacklist);
    integer n;
    for (n=1; n <= num_blacklisted/2; n = n + 1)
    {
        string name = llList2String(blacklist, 2*n-1);
        if (name != "")
        {
          prompt += "\n" + (string)(n) + " - " + name;
          buttons += [(string)(n)];
         }
    }  
    buttons += [UPMENU, "Remove All"];
    buttons = RestackMenu(buttons);
    requesttype = "rem blacklisted"; 
    listener = llListen(listenchannel, "", id, "");
    llDialog(id, prompt, buttons, listenchannel);
    //the menu needs to time out
    llSetTimerEvent(45.0);
}

list RestackMenu(list in)
{ //adds empty buttons until the list length is multiple of 3, to max of 12
    while (llGetListLength(in) % 3 != 0 && llGetListLength(in) < 12)
    {
        in += [" "];
    }
    //look for ^ and > in the menu
    integer m = llListFindList(in, [MORE]);
    if (m != -1)
    {
        in = llDeleteSubList(in, m, m);
    }
    integer u = llListFindList(in, [UPMENU]);
    if (u != -1)
    {
        in = llDeleteSubList(in, u, u);
    }
    //re-orders a list so dialog buttons start in the top row
    list out = llList2List(in, 9, 11);
    out += llList2List(in, 6, 8);
    out += llList2List(in, 3, 5);    
    out += llList2List(in, 0, 2);
    //make sure we move ^ and > to position 1 and 2
    if (u != -1)
    {
        out = llListInsertList(out, [UPMENU], 1);
    }
    if (m != -1)
    {
        out = llListInsertList(out, [MORE], 2);
    }

    return out;
}

integer UserAuth(string id)
{
    integer auth;
    if (id == owner)
    {
        auth = COMMAND_OWNER;
    }
    else if (~llListFindList(blacklist, [(string)id]))
    {
        auth = COMMAND_BLACKLIST;
    }
    else if (~llListFindList(secowners, [(string)id]))
    {
        auth = COMMAND_SECOWNER;
    }
    else if (id == wearer)
    {
        auth = COMMAND_WEARER;
    }
    else if ((openaccess || (llSameGroup(id) && groupenabled && id != wearer)))
    {
        auth = COMMAND_GROUP;
    }            
    else
    {
        auth = COMMAND_EVERYONE;
    }
    return auth;
}

integer ObjectAuth(key obj, key objownerkey)
{
    integer auth;
    if (objownerkey == owner)
    {
        auth = COMMAND_OWNER;
    }
    else if (~llListFindList(secowners, [(string)objownerkey]))
    {
        auth = COMMAND_SECOWNER;          
    }
    else if ((openaccess || ((key)llList2String(llGetObjectDetails(obj, [OBJECT_GROUP]), 0) == group && objownerkey != wearer && group != NULL_KEY))&&(llListFindList(blacklist,[llGetOwnerKey(obj)])==-1))
    {  //meaning that the command came from an object set to our control group, and is not owned by the wearer
        auth = COMMAND_GROUP;
    }             
    else if (objownerkey == wearer)
    {
        auth = COMMAND_WEARER;
    }
    else
    {
        auth = COMMAND_EVERYONE;
    }            
    return auth; 
}


SendOwnerSettings(key id)
{
    Notify(id, "Owner: " + ownername + " (" + (string)owner + ")",FALSE);
    //Do Secowners list            
    integer n;
    integer length = llGetListLength(secowners);
    string sostring;
    for (n = 0; n < length; n = n + 2)
    {
        sostring += "\n" + llList2String(secowners, n + 1) + " (" + llList2String(secowners, n) + ")";
    }
    Notify(id, "Secowners: " + sostring,FALSE);                        
    length = llGetListLength(blacklist);
    string blstring;
    for (n = 0; n < length; n = n + 2)
    {
        blstring += "\n" + llList2String(blacklist, n + 1) + " (" + llList2String(blacklist, n) + ")";
    }
    Notify(id, "Black List: " + blstring,FALSE);                        
    Notify(id, "Group: " + groupname,FALSE);            
    Notify(id, "Group Key: " + (string)group,FALSE);     
    string val; if (openaccess) val="true"; else val="false";
    Notify(id, "Open Access: "+ val,FALSE);
}

integer RemSecOwner(string name)
{
    debug("removing: " + name);    
    //all our comparisons will be cast to lower case first
    name = llToLower(name);
    integer found = FALSE;
    integer n;
    //loop from the top and work down, so we don't skip when we remove things
    for (n = llGetListLength(secowners) - 1; n >= 0; n = n - 2)
    {
        string thisname = llToLower(llList2String(secowners, n));
        debug("checking " + thisname);        
        if (name == thisname)
        {   //remove name and key
            secowners = llDeleteSubList(secowners, n - 1, n);
            found = TRUE;
        }
    }
    //return TRUE if name found, else FALSE
    if (found)
    {
        if (llGetListLength(secowners)>0)
        {
            llMessageLinked(LINK_THIS, HTTPDB_SAVE, "secowners=" + llDumpList2String(secowners, ","), NULL_KEY);
        }
        else
        {
            llMessageLinked(LINK_THIS, HTTPDB_DELETE, "secowners", NULL_KEY);
        }
        //added for attachment interface to announce owners have changed
        llWhisper(interfaceChannel, "CollarCommand|499|OwnerChange");                     
    }
    return found;
}

integer RemBlackListed(string name)
{
    debug("removing: " + name);    
    //all our comparisons will be cast to lower case first
    name = llToLower(name);
    integer found = FALSE;
    integer n;
    //loop from the top and work down, so we don't skip when we remove things
    for (n = llGetListLength(blacklist) - 1; n >= 0; n = n - 2)
    {
        string thisname = llToLower(llList2String(blacklist, n));
        debug("checking " + thisname);        
        if (name == thisname)
        {   //remove name and key
            blacklist = llDeleteSubList(blacklist, n - 1, n);
            found = TRUE;
        }
    }
    //return TRUE if name found, else FALSE
    if (found)
    {
        if (llGetListLength(blacklist)>0)
        {
            llMessageLinked(LINK_THIS, HTTPDB_SAVE, "blacklist=" + llDumpList2String(blacklist, ","), NULL_KEY);
        }
        else
        {
            llMessageLinked(LINK_THIS, HTTPDB_DELETE, "blacklist", NULL_KEY);
        }
    }
    return found;
}

integer isKey(string in) {
    if ((key)in) return TRUE;
    
    return FALSE;
}


default
{
    state_entry()
    {   //until set otherwise, wearer is owner
        wearer = llGetOwner();
        owner = wearer;
        ownername = llKey2Name(wearer);
        listenchannel = -99999 - llRound(llFrand(9999999.0));
        //added for attachment auth
        interfaceChannel = (integer)("0x" + llGetSubString(wearer,30,-1));
        if (interfaceChannel > 0) interfaceChannel = -interfaceChannel;    
         /* // no more needed
        llSleep(1.0);//giving time for others to reset before populating menu        
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);                  */
    }
    
    link_message(integer sender, integer num, string str, key id)
    {  //authenticate messages on COMMAND_NOAUTH
        if (num == COMMAND_NOAUTH)
        {
            integer auth = UserAuth((string)id);
            llMessageLinked(LINK_SET, auth, str, id);              
            debug("noauth: " + str + " from " + (string)id + " who has auth " + (string)auth);                 
        }
        else if (num == COMMAND_OBJECT)
        {   //on object sent a command, see if that object's owner is an owner or secowner in the collar
            //or if the object is set to the same group, and group is enabled in the collar
            //or if object is owned by wearer
            key objownerkey = llGetOwnerKey(id);   
            integer auth = ObjectAuth(id, objownerkey);
            llMessageLinked(LINK_SET, auth, str, id);              
            debug("noauth: " + str + " from object " + (string)id + " who has auth " + (string)auth);
        }
        else if ((str == "settings" || str == "listowners") && num >= COMMAND_OWNER && num <=COMMAND_WEARER)
        {   //say owner, secowners, group
            SendOwnerSettings(id);    
        }     
        else if ((str == "owners") && num >= COMMAND_OWNER && num <=COMMAND_WEARER)
        {   //give owner menu
            AuthMenu(id);    
        }     
        else if (num == COMMAND_OWNER)
        { //respond to messages to set or unset owner, group, or secowners.  only owner may do these things            
            list params = llParseString2List(str, [" "], []);
            string command = llList2String(params, 0);
            if (command == "owner")
            { //set a new owner.  use w-hat name2key service.  benefits: not case sensitive, and owner need not be present
                //if no owner at all specified:
                if (llList2String(params, 1) == "")
                {
                    AuthMenu(id);
                    return;
                }
                requesttype = "owner";
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                //record owner name
                tmpname = llDumpList2String(params, " ");
                //sensor for the owner name to get the key or set the owner directly if it is the wearer
                if(llToLower(tmpname) == llToLower(llKey2Name(wearer)))
                {
                    SetOwner(wearer);
                }
                else
                {
                    llSensor("","", AGENT, 20.0, PI);
                }
            }
            else if (command == "secowner")
            { //set a new secowner
                requesttype = "secowner";
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                //record owner name
                tmpname = llDumpList2String(params, " ");
                if (tmpname=="")
                {
                    requesttype = "setsecowner";
                    llSensor("", "", AGENT, 10.0, PI);
                }
                else if (SecOwnerExists(tmpname))
                {  //error
                    Notify(id, "Error: " + tmpname + " is already in the secowner list.",FALSE);
                }
                else if (llGetListLength(secowners) == 20)
                {
                    Notify(id, "The maximum of 10 secowners is reached, please clean up or use SetGroup",FALSE);
                }
                else
                {//sensor for the owner name to get the key or set the owner directly if it is the wearer
                    if(llToLower(tmpname) == llToLower(llKey2Name(wearer)))
                    {
                        SetOwner(wearer);
                    }
                    else
                    {
                        llSensor("","", AGENT, 20.0, PI);
                    }
                }             
            }
            else if (command == "remsecowner")//i don't like this command.  see what amethyst uses
            { //remove secowner, if in the list
                requesttype = "remsecowner";
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                //name of person concerned
                tmpname = llDumpList2String(params, " ");
                if (tmpname=="")
                {
                    RemSecOwnerMenu(id);
                }
                else if(llToLower(tmpname) == "remove all")
                {
                    secowners = [];
                    llMessageLinked(LINK_THIS, HTTPDB_DELETE, "secowners=", NULL_KEY);
                    Notify(id, "Everybody was removed from the secondary owner list!",TRUE);
                }
                else if (RemSecOwner(tmpname))
                {
                    Notify(id, tmpname + " removed from secondary owner list.", TRUE);
                }
                else
                {
                    Notify(id, "Error: '" + tmpname + "' not in secondary owner list.",FALSE);     
                }                                                          
            }
            else if (command == "blacklist")
            { //blacklist an avatar
                requesttype = "blacklist";
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                //record blacklisted name
                tmpname = llDumpList2String(params, " ");
                if (tmpname=="")
                {
                    requesttype = "setblacklist";
                    llSensor("", "", AGENT, 10.0, PI);
                }
                else if (BlackListExists(tmpname))
                {  //error
                    Notify(id, "Error: " + tmpname + " is already blacklisted.",FALSE);
                }
                else if (llGetListLength(blacklist) == 20)
                {
                    Notify(id, "The maximum of 10 blacklisted is reached, please clean up.",FALSE);
                }
                else
                {   //sensor for the blacklisted name to get the key
                    llSensor("","", AGENT, 20.0, PI);
//                  Name2Key(llDumpList2String(params, "+")); // do this only if avi not nearby
                }             
            }
            else if (command == "remblacklist")
            { //remove blacklisted, if in the list
                requesttype = "remblacklist";
                //pop the command off the param list, leaving only first and last name
                params = llDeleteSubList(params, 0, 0);
                //name of person concerned
                tmpname = llDumpList2String(params, " ");
                if (tmpname=="")
                {
                    RemBlackListMenu(id);
                }
                else if(llToLower(tmpname) == "remove all")
                {
                    blacklist = [];
                    llMessageLinked(LINK_THIS, HTTPDB_DELETE, "blacklist=", NULL_KEY);
                    Notify(id, "Everybody was removed from black list!", TRUE);
                }
                else if (RemBlackListed(tmpname))
                {
                    Notify(id, tmpname + " removed from black list.", TRUE);
                }
                else
                {
                    Notify(id, "Error: '" + tmpname + "' not in black list.", FALSE);     
                }                                                          
            }
            else if (command == "setgroup")
            {
                requesttype = "group";
                //if no arguments given, use current group, else use key provided
                if (isKey(llList2String(params, 1)))
                {
                    group = (key)llList2String(params, 1);
                }
                else
                {
                    //record current group key
                    group = (key)llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0);                    
                }
                
                //in case someone tries to set this with no group set
                if (group != NULL_KEY)
                {
                    llMessageLinked(LINK_THIS, HTTPDB_SAVE, "group=" + (string)group, NULL_KEY);           
                    groupenabled = TRUE;
                    GetGroupName(group);                    
                }
                if(remenu)
                {
                    remenu = FALSE;
                    AuthMenu(id);
                }
            }
            else if (command == "setgroupname")
            {
                groupname = llDumpList2String(llList2List(params, 1, -1), " ");
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "groupname=" + groupname, NULL_KEY);
            }
            else if (command == "unsetgroup")
            {
                group = NULL_KEY;
                groupname = "";
                llMessageLinked(LINK_THIS, HTTPDB_DELETE, "group", NULL_KEY);                          
                llMessageLinked(LINK_THIS, HTTPDB_DELETE, "groupname", NULL_KEY);                
                groupenabled = FALSE;
                Notify(id, "Group unset.", FALSE);
                if(remenu)
                {
                    remenu = FALSE;
                    AuthMenu(id);
                }
                //added for attachment interface to announce owners have changed
                llWhisper(interfaceChannel, "CollarCommand|499|OwnerChange");
            }
            else if (command == "setopenaccess")
            {
                openaccess = TRUE;
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "openaccess=" + (string) openaccess, NULL_KEY);
                Notify(id, "Open access set.", FALSE);
                if(remenu)
                {
                    remenu = FALSE;
                    AuthMenu(id);
                }
            }
            else if (command == "unsetopenaccess")
            {
                openaccess = FALSE;
                llMessageLinked(LINK_THIS, HTTPDB_DELETE, "openaccess", NULL_KEY);
                Notify(id, "Open access unset.", FALSE);
                if(remenu)
                {
                    remenu = FALSE;
                    AuthMenu(id);
                }
                //added for attachment interface to announce owners have changed
                llWhisper(interfaceChannel, "CollarCommand|499|OwnerChange");
            }
             /* // no more self - resets
            else if (command == "reset")
            { //tell owner and wearer about reset
                Notify(owner, "Resetting...", FALSE);
                //reset script, forgetting owner, group, secowners
                llResetScript();      
            }
            */
        }
        else if (num==COMMAND_WEARER||(id==wearer&&num==COMMAND_SECOWNER)) //num == COMMAND_WEARER) <- temporary hack until a better auth system is found
        {
            list params = llParseString2List(str, [" "], []);
            string command = llList2String(params, 0);            
            if (command == "runaway" || command == "reset")
            {    //IM Owner
                Notify(owner, llKey2Name(wearer) + " has run away!",FALSE);                
                Notify(wearer, "Running away from " + ownername,FALSE);  
                 /* // no more self - resets             
                //reset, forgetting owner, group, secowners
                llResetScript();
                */
            }
        }
        else if (num == HTTPDB_RESPONSE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            if (token == "owner")
            {
                list tmp = llParseString2List(value, [","], []);
                owner = (key)llList2String(tmp, 0);                
                ownername = llList2String(tmp, 1);
                if (owner != wearer && !notified)
                {
                    ownerOnlineCheck = llRequestAgentData(owner,DATA_ONLINE);
                }
            }
            else if (token == "group")
            {
                group = (key)value;
                //check to see if the object's group is set properly
                if (group != NULL_KEY)
                {
                    if ((key)llList2String(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0) == group)
                    {
                        groupenabled = TRUE;
                    }
                    else
                    {
                        groupenabled = FALSE;
                    }
                }
                else
                {
                    groupenabled = FALSE;
                }                        
            }
            else if (token == "groupname")
            {
                groupname = value;
            }
            else if (token == "openaccess")
            {
                openaccess = (integer)value;
            }
            else if (token == "secowners")
            {
                secowners = llParseString2List(value, [","], [""]);
                string readablelist;
                integer n;
                integer length = llGetListLength(secowners);
                for (n = 0; n < length; n = n + 2)
                {
                    if (n == 0)
                    {
                        readablelist += llList2String(secowners, n + 1);
                    }
                    else
                    {
                        readablelist += ", " + llList2String(secowners, n + 1);                        
                    }
                }
            }
            else if (token == "blacklist")
            {
                blacklist = llParseString2List(value, [","], [""]);
                string readablelist;
                integer n;
                integer length = llGetListLength(blacklist);
                for (n = 0; n < length; n = n + 2)
                {
                    if (n == 0)
                    {
                        readablelist += llList2String(blacklist, n + 1);
                    }
                    else
                    {
                        readablelist += ", " + llList2String(blacklist, n + 1);                        
                    }
                }
            }
        }
        else if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        else if (num == SUBMENU && str == submenu) AuthMenu(id);                
        else if (num == COMMAND_SAFEWORD)
        {
            string subName = llKey2Name(wearer);
            string subFistName = llList2String(llParseString2List(subName, [" "], []), 0);
            Notify(owner, "Your sub " + subName + " has used the safeword. Please check on " + subFistName +"'s well-being and if further care is required.",FALSE);
            //added for attachment interface (Garvin)
            llWhisper(interfaceChannel, "CollarCommand|499|safeword");
        }
        //added for attachment auth (Garvin)
        else if (num == ATTACHMENT_REQUEST)
        {
            integer auth = UserAuth((string)id);
            llMessageLinked(LINK_THIS, ATTACHMENT_RESPONSE, (string)auth, id);
        }
    }    
    
    listen(integer channel, string name, key id, string message)
    {
        if (message == UPMENU)
        {
            llMessageLinked(LINK_THIS, SUBMENU, parentmenu, id);
            return;
        }
        else if (message == setowner)
        {   //for now, give a popup saying how to set owner in chat.
            if(id == owner)
            {
                requesttype = "setowner";
                llSensor("", "", AGENT, 10.0, PI);
            }
            else
            {
                Notify(id, "Only the owner can set a new owner.",FALSE);
            }
            return;
//            llMessageLinked(LINK_THIS, POPUP_HELP, "To set owner, say _PREFIX_owner and the owner name.  Example: _PREFIX_owner Nandana Singh", id);
        }
        else if (message == setsecowner)
        {   //for now, give a popup saying how to set secowner in chat.
            if(id == owner)
            {
                requesttype = "setsecowner";
                llSensor("", "", AGENT, 10.0, PI);
            }
            else
            {
                Notify(id, "Only the owner can add or remove secowners.",FALSE);
            }
            return;
//            llMessageLinked(LINK_THIS, POPUP_HELP, "To add a secowner, say _PREFIX_secowner and the name.  Example: _PREFIX_secowner Nandana Singh", id);                
        }
        else if (message == setblacklist)
        {   //for now, give a popup saying how to set secowner in chat.
            if(id == owner)
            {
                requesttype = "setblacklist";
                llSensor("", "", AGENT, 10.0, PI);
            }
            else
            {
                Notify(id, "Only the owner can add or remove from black list.",FALSE);
            }
            return;
//            llMessageLinked(LINK_THIS, POPUP_HELP, "To add a secowner, say _PREFIX_secowner and the name.  Example: _PREFIX_secowner Nandana Singh", id);                
        }
        else if (message == setgroup)
        {
            remenu = TRUE;
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "setgroup", id);
            return;
        }
        else if (message == setopenaccess)
        {
            remenu = TRUE;
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "setopenaccess", id);
            return;
        }
        else if (message == unsetopenaccess)
        {
            remenu = TRUE;
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "unsetopenaccess", id);
            return;
        }
        else if (message == reset)
        {
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "reset", id);            
        }
        else if (message == remsecowner)
        {   //popup list of secowner if owner clicked
            if (id == owner)
            {
                RemSecOwnerMenu(id);
            }
            else
            {
                Notify(id, "Only the owner can add or remove secowners.",FALSE);
            }
            return;
        }
        else if (message == remblacklist)
        {   //popup list of secowner if owner clicked
            if (id == owner)
            {
                RemBlackListMenu(id);
            }
            else
            {
                Notify(id, "Only the owner can add or remove from black list.",FALSE);
            }
            return;
        }
        else if (message == unsetgroup)
        {
            remenu = TRUE;
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "unsetgroup", id);
            return;           
        }
        else if (message == listowners)
        {
            llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "listowners", id);            
        }
        else if ((integer)message)
        {
            if(id == owner)
            {
                if(requesttype == "rem secowner")
                {//need to send the command to auth to see if authorized to remove
                    string remSecOwner = "remsecowner " + llList2String(secowners, (integer)message*2 - 1);
                    llMessageLinked(LINK_THIS, COMMAND_OWNER, remSecOwner, id);
                }
                else if(requesttype == "rem blacklisted")
                {//need to send the command to auth to see if authorized to remove
                    string remBlackListed = "remblacklist " + llList2String(blacklist, (integer)message*2 - 1);
                    llMessageLinked(LINK_THIS, COMMAND_OWNER, remBlackListed, id);
                }
            }
            else
            {
                Notify(id, "Only the owner can add or remove secowners and blacklisted avatars.",FALSE);
            }
        }
        else if (message == "Remove All")
        {
            if(id == owner)
            {
                if(requesttype == "rem secowner")
                {               
                    llMessageLinked(LINK_THIS, COMMAND_OWNER, "remsecowner Remove All", id);
                }
                else if(requesttype == "rem blacklisted")
                {
                    llMessageLinked(LINK_THIS, COMMAND_OWNER, "remblacklist Remove All", id);
                }
            }
            else
            {
                Notify(id, "Only the owner can add or remove secowners.",FALSE);
            }
        }
        else if(requesttype == "setowner")
        {
            llMessageLinked(LINK_THIS, COMMAND_OWNER, "owner " + message, id);
        }
        else if(requesttype == "setsecowner")
        {
            llMessageLinked(LINK_THIS, COMMAND_OWNER, "secowner " + message, id);
        }
        else if(requesttype == "setblacklist")
        {
            llMessageLinked(LINK_THIS, COMMAND_OWNER, "blacklist " + message, id);
        }
        AuthMenu(id);
    }
    
    sensor(integer num_detected)
    {
        if(requesttype == "owner" || requesttype == "secowner" || requesttype == "blacklist")
        {
            integer i;
            integer foundAvi = FALSE;
            for (i = 0; i < num_detected; i++)
            {
                if(llToLower(tmpname) == llToLower(llDetectedName(i)))
                {
                    foundAvi = TRUE;
                    SetOwner(llDetectedKey(i));
                    i = num_detected;                
                }
            }
            if(!foundAvi)
            {
                if(tmpname == llKey2Name(wearer))
                {
                    SetOwner(llKey2Name(wearer));
                }
                else
                {
                    list temp = llParseString2List(tmpname, [" "], []);
                    Name2Key(llDumpList2String(temp, "+"));
                }
            }
        }
        else if(requesttype == "setowner" || requesttype == "setsecowner" || requesttype == "setblacklist")
        {
            list temp;
            string newOwner;
            if (requesttype == "setsecowner")
            {
                newOwner = llKey2Name(wearer);
                if (!SecOwnerExists(newOwner) && llStringLength(newOwner) <= 24)
                {
                    temp = [newOwner];
                    if(num_detected > 10)
                    {
                        num_detected = 10;
                    }
                }
            }
            if(num_detected > 11)
            {
                num_detected = 11;
            }
            integer i;
            string text;
            if(requesttype == "setowner")
            {
                text = "Please choose a new owner from the list.";
            }
            else if(requesttype == "setsecowner")
            {
                text = "Please choose who to add as secowner from the list.";
            }
            else if(requesttype == "setblacklist")
            {
                text = "Please choose who to blacklist from this list.";
            }
            
            for(i = 0; i < num_detected; i++)
            {
                if( llDetectedKey(i) != owner)
                {
                    newOwner = llDetectedName(i);
                    if(llStringLength(newOwner) > 24)
                    {
                        Notify(owner, newOwner + " cannot be displayed in the menu and can only be added by command.",FALSE);
                    }
                    else
                    {
                        temp += [newOwner];
                    }
                }
            }
            listener = llListen(listenchannel, "", owner, "");
            temp += [UPMENU];
            temp = RestackMenu(temp);
            text = "\nIf the one you want to add does not show, move closer and repeat or use the chat command.";
            llDialog(owner, text, temp, listenchannel);
            llSetTimerEvent(45.0);
        }
    }
    
    no_sensor()
    {
        if(requesttype == "owner" || requesttype == "secowner" || requesttype == "blacklist")
        {
            list temp = llParseString2List(tmpname, [" "], []);
            Name2Key(llDumpList2String(temp, "+"));
        }
        else if(requesttype == "setowner" || requesttype == "setsecowner" || requesttype == "setblacklist")
        {
            Notify(owner, "Nobody is in 10m range to be shown, either move closer or use the chat command to add someone who is not with you at this moment or offline.",FALSE);
        }
    }
    
    on_rez(integer param)
    {
        //Nan: What's the point of setting a variable right before resetting?
        //notified = FALSE;
        llResetScript();
    }
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER)
        {
            wearer = llGetOwner();
        }
    }
    
    http_response(key id, integer status, list meta, string body)
    {
        if (id == httpid && status == 200)
        {   //here's where we add owners or secowners, after getting their keys
            if (body == "00000000-0000-0000-0000-000000000000")
            {    //owner name not in name2key database
                Popup(owner, "Error: unable to retrieve key for '" + tmpname + "'.");
            }
            else if (requesttype == "owner" || requesttype == "secowner" || requesttype == "blacklist")
            {   //new function added
                if (isKey(body))
                {
                    SetOwner((key)body);
                }
                else
                {
                    llOwnerSay("Error looking up key: " + body);
                }
            }
            else if (requesttype == "group")
            {
                groupname = body;
                llMessageLinked(LINK_THIS, HTTPDB_SAVE, "groupname=" + groupname, NULL_KEY);                
                if (groupname == "X")
                {
                    Popup(owner, "Group set to (group name hidden)");
                }
                else
                {
                    Popup(owner, "Group set to " + groupname);
                }
            }
        }
    }
    
    timer()
    {
        llSetTimerEvent(0);
        llListenRemove(listener);
    }
    
    dataserver(key queryid, string data) {
        if (queryid == ownerOnlineCheck) {
            string msg = "You are owned by " + ownername + ".  Your owner is currently ";
            if ((integer)data) {
                msg += "online.";
            } else {
                msg += "offline.";
            }
            llOwnerSay(msg);
            notified = TRUE;
        }
    }
}
