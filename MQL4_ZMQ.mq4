//+------------------------------------------------------------------+
//|                                                     MQL4_ZMQ.mq4 |
//|                                      Copyright 2014, Peter Kempf |
//|                                                                  |
//| FOR ZEROMQ USE NOTES PLEASE REFERENCE:                           |
//|                           http://api.zeromq.org/2-1:_start       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014 Peter Kempf"
#property link      "http://www.mql4zmq.org"

// Runtime options to specify.
extern string ZMQ_transport_protocol = "tcp";
extern string ZMQ_server_address = "*";
extern string ZMQ_inbound_port = "5555";
extern string ZMQ_outbound_port = "5556";
extern bool Wait_for_Message = false;
extern bool Get_Info = false;
extern bool Testmode = true;
extern int EMA_long = 180;
extern int EMA_short = 60;
extern int MagicNumber = 11041963;

// Include the libzmq.dll abstration wrapper.
#include <mql4zmq.mqh>
// Include the OrderManager.
#include <OrderManager.mqh>

//+------------------------------------------------------------------+
//| variable definitions                                             |
//+------------------------------------------------------------------+
int speaker, listener, ctx;
bool speaker_connected = false;
bool listener_connected = false;
string uid;

struct trade_settings {
  string cmd;           // Kommando  (set|reset|unset|get|draw|parameter)
  string ticket;        // Ticket ID  (123456789)
  string magic_number;  // MagicNumber
  string type;          // Type 
                        // 0 = (MQL4) OP_BUY - buying position,
                        // 1 = (MQL4) OP_SELL - selling position,
                        // 2 = (MQL4) OP_BUYLIMIT - buy limit pending position,
                        // 3 = (MQL4) OP_SELLLIMIT - sell limit pending position,
                        // 4 = (MQL4) OP_BUYSTOP - buy stop pending position,
                        // 5 = (MQL4) OP_SELLSTOP - sell stop pending position.
  string pair;          // Symbol (EURUSD)
  string open_price;    // Open Price (1.24)
  string slippage;      // Max. Abweichung in Prozent (0.03)
  string take_profit;   // Take Profit (1.255)
  string stop_loss;     // Stop Loss (1.235)
  string lot;           // Lot Size (0.5)
  string comment;       // Comment
  string object_type;   // Object Type
  string window;        // Window
  string open_time;     // Open Time
  string close_time;    // CLose Time
  string close_price;   // Close Price
  string prediction;    // Prediction
  string referenz;      // Externe Referenz
  string name;          // Parameter Name
  string value;         // Requested/Set Value
};
  
trade_settings settings = {"", "", "", "", "", "", "", "", "", "", NULL, "", "", "", "", "", "", ""}; 
  

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
//----

  settings.magic_number = IntegerToString(MagicNumber);
  
  OrderManager_Init();
  
  int major[1];int minor[1];int patch[1];
  zmq_version(major,minor,patch);
  Print("Using zeromq version " + IntegerToString(major[0]) + "." + IntegerToString(minor[0]) + "." + IntegerToString(patch[0]));
   
  Print(ping("Hello World"));
   
  // Define ZMQ Objects
  ctx      = zmq_init(1);
  speaker  = zmq_socket(ctx, ZMQ_PUB);
  listener = zmq_socket(ctx, ZMQ_SUB);
  
  // Subscribe to the command channel (i.e. "cmd").  
  // NOTE: to subscribe to multiple channels call zmq_setsockopt multiple times.
  string command_string = "cmd|" + IntegerToString(AccountNumber());
  zmq_setsockopt(listener, ZMQ_SUBSCRIBE, command_string);
  Print("Listening for commands on channel: " + command_string); // Output command string.
  
  // Connect/Bind Listener and Speaker 
  listener_connected = connect_Listener();
  speaker_connected  = connect_Speaker();
  
//----
  return(0);
}


//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() {
//----

  // Delete all objects from the chart.
  for(int i=ObjectsTotal()-1; i>-1; i--) {
    ObjectDelete(ObjectName(i));
  }
  Comment("");
   
  // Send Notification that bridge is down.
  // Format: bridge|testaccount DOWN
  string bridge_down = "status|" + IntegerToString(AccountNumber()) + " bridge {\"status\": \"down\"}";
  if (s_send(speaker, bridge_down) == -1) Print("Error sending message: " + bridge_down);
  else                                    Print("Published message: " + bridge_down);
   
  // Protect against memory leaks on shutdown.
  zmq_close(speaker);
  zmq_close(listener);
  zmq_term(ctx);

//----
  return(0);
}


//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {

//----
   
  // Note: If we do NOT specify ZMQ_NOBLOCK it will wait here until 
  //       we recieve a message. This is a problem as this function
  //       will effectively block the MQL4 'Start' function from firing
  //       when the next tick arrives if no message has arrived from 
  //       the publisher. If you want it to block and, therefore, instantly
  //       receive messages (doesn't have to wait until next tick) then
  //       change the below line to:
  //       
  //       string message = s_recv(listener);
  //
  
  // First Part: Read message
  string message, response;

  if (connect_Listener()) {
    if (Wait_for_Message) {
      message = s_recv(listener);
    } else {
      message = s_recv(listener, ZMQ_NOBLOCK);
    }


    // Second Part: Analyse message and execute command
    if (message != "") {                                     // Will return NULL if no message was received.
      Print("Received message: " + message);
      message_get_settings(message);                         // Determine Message settings
      StringToLower(message);
    
      // cmd reset: Set new Trade Parameter
      if (settings.cmd == "reset") {                        // cmd reset
        bool update_ticket = false;
        if (OrderSelect(StrToInteger(settings.ticket), SELECT_BY_TICKET)) { // Select the requested order.
          if (settings.open_price == "") {                     // Since 'open_price' was not received, we know that we're updating a trade.
            if (Testmode == false) {
              update_ticket = OrderModify(OrderTicket(),         // Send the trade modify instructions.
                                          OrderOpenPrice(),      
                                          NormalizeDouble(StrToDouble(settings.stop_loss), Digits),
                                          NormalizeDouble(StrToDouble(settings.take_profit), Digits), 
                                          0,
                                          Blue);
            } else {
              update_ticket = true;
            }
          } else {                                             // Since 'open_price' was received, we know that we're updating an order.
            Print(NormalizeDouble(StrToDouble(settings.open_price), Digits));
            if (Testmode == false) {
              update_ticket = OrderModify(OrderTicket(),         // Send the order modify instructions.
                                          NormalizeDouble(StrToDouble(settings.open_price), Digits),
                                          NormalizeDouble(StrToDouble(settings.stop_loss), Digits),
                                          NormalizeDouble(StrToDouble(settings.take_profit), Digits), 
                                          0, 
                                          Blue);
            } else {
              update_ticket = true;
            }
          }
        }
                  
        if (update_ticket == false) {
          Print("OrderSend/OrderSelect failed with error #", GetLastError());
          return(0);
        } else {
          if (settings.open_price == "") {
            Print("Trade: " + settings.ticket + " updated stop loss to: " + settings.stop_loss + " and take profit to: " + settings.take_profit);
          } else {
            Print("Order: " + settings.ticket + " updated stop loss to: " + settings.stop_loss + ", take profit to: " + settings.take_profit + ", and open price to: " + settings.open_price);
          }
          response = "Order has been modified:" + settings.ticket;
          if (send_response(uid, response) == false) // Send response.
            Print("ERROR occurred sending response!");
        }
      
      // cmd unset: Close Trade
      } else if (settings.cmd == "unset") {                  // cmd unset
        bool close_ticket  = false;
        if (OrderSelect(StrToInteger(settings.ticket), SELECT_BY_TICKET)) { // Select the requested order and send the oder close instructions.
          if (Testmode == false) {
            if (OrderType() == OP_BUY) {
              close_ticket = OrderClose(OrderTicket(), OrderLots(), Bid, 3, Red);
            } else if (OrderType() == OP_SELL) {
              close_ticket = OrderClose(OrderTicket(), OrderLots(), Ask, 3, Red);
            } else if (OrderType() == OP_BUYLIMIT || OrderType() == OP_BUYSTOP || OrderType() == OP_SELLLIMIT || OrderType() == OP_SELLSTOP) {
              close_ticket = OrderDelete(OrderTicket());
            }
          } else {
            close_ticket = true;
          }
        }   
        if (close_ticket == false) {
          Print("OrderSend/OrderSelect failed with error #",GetLastError());
          return(0);
        } else {
          Print("Closed trade: " + settings.ticket);
          response = "Order has been closed:" + settings.ticket;
          if (send_response(uid, response) == false) // Send response.
            Print("ERROR occurred sending response!");
        }

      // cmd set: Open Trade
      } else if (settings.cmd == "set") {                    // cmd set
        Print(settings.type + " " + settings.pair + ", Open: " + settings.open_price + ", TP: " + settings.take_profit + ", SL: " + settings.stop_loss + ", Lots: " + settings.lot); 

        // Falls ein Open_Price mitgegeben wurde, wird anhand des aktuellen Preises und settings.slippage entscheiden, ob die Order 
        // marktausgefuehrt wird oder als BUYLIMIT/STOPLIMIT oder garnicht.
        // Eventuell kann der 5. Parameter von OrderSend (slippage) auch verwendet werden
        // Moegliche Werte fuer settings.type:
        // 0 = (MQL4) OP_BUY - buying position,
        // 1 = (MQL4) OP_SELL - selling position,
        // 2 = (MQL4) OP_BUYLIMIT - buy limit pending position,
        // 3 = (MQL4) OP_SELLLIMIT - sell limit pending position,
        // 4 = (MQL4) OP_BUYSTOP - buy stop pending position,
        // 5 = (MQL4) OP_SELLSTOP - sell stop pending position.
        //
        // Moegliche Umstellungen
        // OP_BUY  -> OP_BUYLIMIT statt Ask
        // OP_SELL -> OP_SELLLIMIT statt Bid
        if (settings.open_price) {
          double myPrice    = StringToDouble(settings.open_price);
          double myAsk      = Ask;
          double myBid      = Bid;
          double mySlippage = StringToDouble(settings.slippage) * myPrice / 100;
          if (settings.type == IntegerToString(OP_BUY)) {
            if ((myAsk - myPrice) > mySlippage) {
              settings.type = IntegerToString(OP_BUYLIMIT);
            } else {
              settings.open_price = DoubleToStr(myAsk);
            }
          } else if (settings.type == IntegerToString(OP_SELL)) {
            if ((myPrice - myBid) > mySlippage) {
              settings.type = IntegerToString(OP_SELLLIMIT);
            } else {
              settings.open_price = DoubleToStr(myBid);
            }
          }
        }
      
        Print(NormalizeDouble(StrToDouble(settings.take_profit), Digits)); // Open trade.
         
        int ticket;
        if (Testmode == false) {
          ticket = OrderSend(StringTrimLeft(settings.pair),
                             StrToInteger(settings.type), 
                             NormalizeDouble(StrToDouble(settings.lot), Digits),
                             NormalizeDouble(StrToDouble(settings.open_price), Digits),
                             3,
                             NormalizeDouble(StrToDouble(settings.stop_loss), Digits),
                             NormalizeDouble(StrToDouble(settings.take_profit), Digits),
                             settings.comment,
                             StrToInteger(settings.magic_number),
                             TimeCurrent() + 3600,
                             Green); 
        } else {
          ticket = 999999999;
        }
        if (ticket < 0) {
          Print("OrderSend failed with error #",GetLastError());
          return(0);
        } else { 
          response = "Order has been send:" + IntegerToString(ticket);
          if (send_response(uid, response) == false) // Send response.
            Print("ERROR occurred sending response!");
        }

      // cmd Draw: Draw Object
      } else if (settings.cmd == "draw") {                   // cmd draw; If a new element to be drawen is requested.
        double bar_uid = MathRand()%10001/10000.0;           // Generate UID
            
        // Draw the rectangle object.
        Print("Drawing: ", settings.type, " ", settings.window, " ", settings.open_time, " ", settings.open_price, " ", settings.close_time, " ", settings.close_price, " ", settings.prediction);
        if (!ObjectCreate("bar:" + DoubleToStr(bar_uid), draw_object_string_to_int(settings.type), StrToInteger(settings.window), StrToInteger(settings.open_time), StrToDouble(settings.open_price), StrToInteger(settings.close_time), StrToDouble(settings.close_price))) {
          Print("error: cannot create object! code #",GetLastError());
          response = "false";
        } else {
          // Color the bar based on the predicted direction. If no prediction was sent than the 
          // 'prediction' keyword will still occupy the array element and we need to set to Gray.
          if (settings.prediction == "") {
            ObjectSet("bar:" + DoubleToStr(bar_uid), OBJPROP_COLOR, Gray);
          } else if (StrToDouble(settings.prediction) > 0.5) {
            ObjectSet("bar:" + DoubleToStr(bar_uid), OBJPROP_COLOR, CadetBlue);
          } else if (StrToDouble(settings.prediction) < 0.5) {
            ObjectSet("bar:" + DoubleToStr(bar_uid), OBJPROP_COLOR, IndianRed);
          } else
            ObjectSet("bar:" + DoubleToStr(bar_uid), OBJPROP_COLOR, Gray);
          response = "true";
        }         
        if (send_response(uid, response) == false) // Send response.
          Print("ERROR occurred sending response!");
    
      // cmd set_parameter: Set Parameter
      } else if (settings.cmd == "set_parameter") {          // cmd set_parameter
        if (settings.name == "get_info") {
            Get_Info = StringToInteger(settings.value);
          if (Get_Info == StringToInteger(settings.value)) {
            response = "true";
          } else {
            response = "false";
          }
        } else if (settings.name  == "wait_for_message") {
          Wait_for_Message = StringToInteger(settings.value);
          if (Wait_for_Message == StringToInteger(settings.value)) {
            response = "true";
          } else {
            response = "false";
          }
        }
        // and so on ...
        if (response != "") {
          if (send_response(uid, response))// Send response.
            Print("ERROR occurred sending response!");
        }

      // cmd get_parameter: Ask for a value
      } else if (settings.cmd == "get_parameter") {          // cmd get_parameter; If requested value is available
        if (settings.name  == "pair") {
          response = Symbol();
        } else if (settings.name  == "isconnected") {
          response = IntegerToString(IsConnected());
        } else if (settings.name  == "digits") {
          response = IntegerToString(Digits());
        }
        // and so on ....
        if (response != "") {
          if (send_response(uid, response))// Send response.
            Print("ERROR occurred sending response!");
        }
      }
    }
        
    return(0);
  }
   
 
  // Third Part: Hedge Orders: Set TP/SL
  manageOrders(MagicNumber);

  // Forth Part: Deliver Bridge Info, Account Info, Order Info, EMA Info and new Tick Info back 
  if (connect_Speaker() && Get_Info) {
    // Publish data.
    //
    // If you need to send a Multi-part message do the following (example is a three part message). 
    //    s_sendmore(speaker, part_1);
    //    s_sendmore(speaker, part_2);
    //    s_send(speaker, part_3);

    string bridge_up = "status|" + IntegerToString(AccountNumber()) + " bridge {\"status\": \"up" +
                                                                           "\", \"pair\": \"" + Symbol() + 
                                                                           "\", \"time\": \"" + TimeToStr(TimeCurrent()) + "\"}";
    if (s_send(speaker, bridge_up) == -1)
      Print("Error sending message: " + bridge_up);
    else
      Print("Published message: " + bridge_up);

    string account = "info|" + IntegerToString(AccountNumber()) + " account {\"leverage\": \""    + IntegerToString(AccountLeverage()) + 
                                                                        "\", \"balance\": \""     + DoubleToStr(AccountBalance()) + 
                                                                        "\", \"margin\": \""      + DoubleToStr(AccountMargin()) + 
                                                                        "\", \"freemargin\": \""  + DoubleToStr(AccountFreeMargin()) + "\"}";
    if (s_send(speaker, account) == -1)                    // Current account info.  
      Print("Error sending message: " + account);
    else
      Print("Published message: " + account);
    
    string ema = "info|" + IntegerToString(AccountNumber()) + " ema {\"pair\": \""      + Symbol() +
                                                                "\", \"ema_long\": \""  + IntegerToString(EMA_long) + 
                                                                "\", \"ima_long\": \""  + DoubleToStr(iMA(Symbol(),0,EMA_long,0,MODE_EMA,PRICE_MEDIAN,0)) + 
                                                                "\", \"ema_short\": \"" + IntegerToString(EMA_short) + 
                                                                "\", \"ima_short\": \"" + DoubleToStr(iMA(Symbol(),0,EMA_short,0,MODE_EMA,PRICE_MEDIAN,0)) + "\"}";
    if (s_send(speaker, ema) == -1)                        // Current EMA info.  
      Print("Error sending message: " + ema);
    else
      Print("Published message: " + ema);
      
    string orders = lookup_open_orders();
    if (s_send(speaker, orders) == -1)                     // Currently open orders.  
      Print("Error sending message: " + orders);
    else
      Print("Published message: " + orders);   

    string tick = "info|" + IntegerToString(AccountNumber()) + " tick {\"pair\": \"" + Symbol() +
                                                                  "\", \"bid\": \""  + DoubleToStr(Bid) + 
                                                                  "\", \"ask\": \""  + DoubleToStr(Ask) +
                                                                  "\", \"time\": \"" + TimeToStr(Time[0]) + "\"}";
    if (s_send(speaker, tick) == -1)                       // Current tick.
      Print("Error sending message: " + tick);
    else
      Print("Published message: " + tick);
  }
//----
  return(0);
}
  
//+------------------------------------------------------------------+
//| Analyses the messages and collect Ticketparameter
//|      => "cmd|[account name] [some command]
//| Returns true if Order could be selected else false    
//+------------------------------------------------------------------+
void message_get_settings(string mymessage) {
  bool rc = false;
  string key, value;
  
  uid = message_get_uid(mymessage);                    // Pull out request uid. Message is formatted: "cmd|[account name]|[uid] reset [ticket_id] [take profit price] [stop loss price] [optional open price]"
  Print("uid: " + uid);                                // ack uid.
  
  // cmd|[account name] {"cmd":"[cmd]", "pair":"[pair]", "type":"[type]", "ticket_id":"[ticket_id]", "open_price":"[open_price]", "take_profit":"[take_profit]", "stop_loss":"[stop_loss]", "open_time":"[open_time]", "expire_time":"[expire_time]", "lots":"[lots]"}
  int start_position = StringFind(mymessage, "{", 0) + 1;
  int end_position = StringFind(mymessage, "}", start_position + 1);
  if (end_position > start_position) mymessage = StringSubstr(mymessage, start_position, end_position - start_position);
  
  while ((start_position >= 0) && (end_position > start_position)) {
    start_position = StringFind(mymessage, "\"", 0) + 1;
    end_position   = StringFind(mymessage, "\"", start_position + 1);
    if ((start_position >= 0) && (end_position > start_position)) {
      key = StringSubstr(mymessage, start_position, end_position - start_position);
      StringToLower(key);
      start_position = StringFind(mymessage, "\"", end_position) + 1;
      end_position   = StringFind(mymessage, "\"", start_position + 1);
      if ((start_position >= 0) && (end_position > start_position)) {
        value = StringSubstr(mymessage, start_position, end_position - start_position);
        mymessage = StringSubstr(mymessage, end_position);
        // Todo Recherchieren, ob indirekte Referenzierung moeglich ist: Gemeint ist bei key=ticket_id und value=1234567  :  settings.ticket = 1234567
        // Leider habe ich das nicht hingekriegt, daher etwas sehr umstaendlich zu Fuss
        // settings.key = value;
        if      (key == "cmd")          settings.cmd          = value;
        else if (key == "ticket")       settings.ticket       = value;
        else if (key == "magic_number") settings.magic_number = value;
        else if (key == "type")         settings.type         = value;
        else if (key == "pair")         settings.pair         = value;
        else if (key == "open_price")   settings.open_price   = value;
        else if (key == "slippage")     settings.slippage     = value;
        else if (key == "take_profit")  settings.take_profit  = value;
        else if (key == "stop_loss")    settings.stop_loss    = value;
        else if (key == "lot")          settings.lot          = value;
        else if (key == "comment")      settings.comment      = value;
        else if (key == "object_type")  settings.object_type  = value;
        else if (key == "window")       settings.window       = value;
        else if (key == "open_time")    settings.open_time    = value;
        else if (key == "close_time")   settings.close_time   = value;
        else if (key == "close_price")  settings.close_price  = value;
        else if (key == "prediction")   settings.prediction   = value;
        else if (key == "referenz")     settings.referenz     = value;
        else if (key == "name")        {StringToLower(value); 
                                        settings.value       = value;}
        else if (key == "value")        settings.value       = value;
      }
    }
  }
}

//+------------------------------------------------------------------+
//| Pulls out the UID for the message. Messages are fomatted:
//|      => "cmd|[account name]|[uid] [some command]
//+------------------------------------------------------------------+
string message_get_uid(string mymessage) {
  string uid_start_string = "cmd|" + IntegerToString(AccountNumber()) + "|";  // Pull out request uid. Message is formatted: "cmd|[accountnumber]|[uid] {[some command and parameter in JSON Format]}"
  int uid_start = StringFind(mymessage, uid_start_string, 0) + StringLen(uid_start_string);
  int uid_end = StringFind(mymessage, " ", 0) - uid_start;
  string myuid = StringSubstr(mymessage, uid_start, uid_end);
  return(myuid);                                           // Return the UID
} 

//+------------------------------------------------------------------+
//| Returns the currently open orders.
//|      => "orders|testaccount1 {"symbol":"EURUSD", "type":"sell", ...}, {... "
//+------------------------------------------------------------------+
string lookup_open_orders() {
  string current_orders = "orders|" + IntegerToString(AccountNumber()) + " "; // Initialize the orders string.
  int total_orders = OrdersTotal();                        // Look up the total number of open orders.
    
  for (int position=0; position < total_orders; position++) { // Build a json-like string for each order and add it to eh current_orders return string. 
    if (OrderSelect(position,SELECT_BY_POS)==false) continue;
    current_orders = current_orders + "{\"ticket\": \""       + IntegerToString(OrderTicket()) + 
                                   "\", \"magic_number\": \"" + IntegerToString(OrderMagicNumber()) + 
                                   "\", \"type\": \""         + IntegerToString(OrderType()) + 
                                   "\", \"pair\": \""         + OrderSymbol() + 
                                   "\", \"open_price\": \""   + DoubleToStr(OrderOpenPrice()) + 
                                   "\", \"take_profit\": \""  + DoubleToStr(OrderTakeProfit()) + 
                                   "\", \"stop_loss\": \""    + DoubleToStr(OrderStopLoss()) + 
                                   "\", \"profit\": \""       + DoubleToStr(OrderProfit()) + 
                                   "\", \"lot\": \""          + DoubleToStr(OrderLots()) + 
                                   "\", \"comment\": \""      + OrderComment() + 
                                   "\", \"open_time\": \""    + TimeToStr(OrderOpenTime()) + 
                                   "\", \"expire_time\": \""  + TimeToStr(OrderExpiration()) + 
                                   "\"}\n";
  }
      
  return(current_orders);                                  // Return the completed string.
}

//+------------------------------------------------------------------+
//| Sends a response to a command. Messages are formatted:
//|      => "response|[account name]|[uid] [some command]
//+------------------------------------------------------------------+
bool send_response(string myuid, string response) {
  string response_string = "response|" + IntegerToString(AccountNumber()) + "|" + myuid + " {\"response\": \"" + response + "\"}"; // Compose response string.

  if (!connect_Speaker() || (s_send(speaker, response_string) == -1)) {        // Send the message.
    Print("Error sending message: " + response_string);
    return(false);
  } else {
    Print("Published message: " + response_string); 
    return(true);
  }
} 

//+------------------------------------------------------------------+
//| Returns the MetaTrader integer value for the string versions of the object types.
//+------------------------------------------------------------------+
int draw_object_string_to_int(string name) {
  int drawing_type_result = -1;                            // Initialize result holder with the error code incase a match is not found.
  // Initialize array of all of the drawing types for MQL4.
  // NOTE: They are in numerical order. I.E. OBJ_VLINE has
  //       a value of '0' and therefore is array element '0'.
  string drawing_types[24] = {
    "OBJ_VLINE", 
    "OBJ_HLINE", 
    "OBJ_TREND", 
    "OBJ_TRENDBYANGLE", 
    "OBJ_REGRESSION", 
    "OBJ_CHANNEL", 
    "OBJ_STDDEVCHANNEL", 
    "OBJ_GANNLINE", 
    "OBJ_GANNFAN",
    "OBJ_GANNGRID",
    "OBJ_FIBO",
    "OBJ_FIBOTIMES",
    "OBJ_FIBOFAN",
    "OBJ_FIBOARC",
    "OBJ_EXPANSION",
    "OBJ_FIBOCHANNEL",
    "OBJ_RECTANGLE",
    "OBJ_TRIANGLE",
    "OBJ_ELLIPSE",
    "OBJ_PITCHFORK",
    "OBJ_CYCLES",
    "OBJ_TEXT",
    "OBJ_ARROW",
    "OBJ_LABEL"
  };
   
  // Cycle throught the array to find a match to the specified 'name' value.
  // Once a match is found, store it's location within the array. This location
  // corresponds to the int value it should have.
  for (int i = 0; i < ArraySize(drawing_types); i++) {
    if(name == drawing_types[i]) {
      drawing_type_result = i;
      break;
    }
  }
   
  // Return the int value the string would have had if it was a pointer of type int.
  switch(drawing_type_result) {           
    case 0 : return(0);          break;               //     Vertical line. Uses time part of first coordinate.
    case 1 : return(1);          break;               //     Horizontal line. Uses price part of first coordinate.
    case 2 : return(2);          break;               //    Trend line. Uses 2 coordinates.
    case 3 : return(3);          break;               //    Trend by angle. Uses 1 coordinate. To set angle of line use ObjectSet() function.
    case 4 : return(4);          break;               //    Regression. Uses time parts of first two coordinates.
    case 5 : return(5);          break;               //    Channel. Uses 3 coordinates.
    case 6 : return(6);          break;               //    Standard deviation channel. Uses time parts of first two coordinates.
    case 7 : return(7);          break;               //    Gann line. Uses 2 coordinate, but price part of second coordinate ignored.
    case 8 : return(8);          break;               //    Gann fan. Uses 2 coordinate, but price part of second coordinate ignored.
    case 9 : return(9);          break;               //    Gann grid. Uses 2 coordinate, but price part of second coordinate ignored.
    case 10 : return(10);        break;               //    Fibonacci retracement. Uses 2 coordinates.
    case 11 : return(11);        break;               //    Fibonacci time zones. Uses 2 coordinates.
    case 12 : return(12);        break;               //    Fibonacci fan. Uses 2 coordinates.
    case 13 : return(13);        break;               //    Fibonacci arcs. Uses 2 coordinates.
    case 14 : return(14);        break;               //    Fibonacci expansions. Uses 3 coordinates.
    case 15 : return(15);        break;               //    Fibonacci channel. Uses 3 coordinates.
    case 16 : return(16);        break;               //    Rectangle. Uses 2 coordinates.
    case 17 : return(17);        break;               //    Triangle. Uses 3 coordinates.
    case 18 : return(18);        break;               //    Ellipse. Uses 2 coordinates.
    case 19 : return(19);        break;               //    Andrews pitchfork. Uses 3 coordinates.
    case 20 : return(20);        break;               //    Cycles. Uses 2 coordinates.
    case 21 : return(21);        break;               //    Text. Uses 1 coordinate.
    case 22 : return(22);        break;               //    Arrows. Uses 1 coordinate.
    case 23 : return(23);        break;               //     Labels.
    default : return(-1);                             //     ERROR. NO MATCH FOUND.
  }
}

//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Connect/Bind Listener                                            |
//+------------------------------------------------------------------+
bool connect_Listener() {
  if (!listener_connected) {
    listener_connected = true;
    string inbound_connection_string = ZMQ_transport_protocol + "://" + ZMQ_server_address + ":" + ZMQ_inbound_port;
    if (ZMQ_server_address == "" || ZMQ_server_address == "*" || ZMQ_server_address == "127.0.0.1") {
      if (zmq_bind(listener, inbound_connection_string) == -1) {
        Print("Error binding the listener to queue " + inbound_connection_string + "!");
        listener_connected = false;
        //  return(-1);
      }
    } else {
      if (zmq_connect(listener, inbound_connection_string) == -1) {
        Print("Error connecting the listener to queue " + inbound_connection_string + "!");
        listener_connected = false;
        //  return(-1);
      }
    }
  }

  return(listener_connected);
}


//+------------------------------------------------------------------+
//| Connect/Bind Speaker                                            |
//+------------------------------------------------------------------+
bool connect_Speaker() {
  if (!speaker_connected) {
    speaker_connected = true;
    string outbound_connection_string = ZMQ_transport_protocol + "://" + ZMQ_server_address + ":" + ZMQ_outbound_port;
    if (ZMQ_server_address == "" || ZMQ_server_address == "*" || ZMQ_server_address == "127.0.0.1") {
      if (zmq_bind(speaker, outbound_connection_string) == -1) {
        Print("Error binding the speaker to queue " + outbound_connection_string + "!");
        speaker_connected = false;
        //  return(-1);
      }
    } else {
      if (zmq_connect(speaker, outbound_connection_string) == -1) {
        Print("Error connecting the speaker to queue " + outbound_connection_string + "!");
        speaker_connected = false;
        //  return(-1);
      }
    }
  }
  if (speaker_connected) {
    // Send Notification that bridge is up.
    // Format: bridge|testaccount {"status": "up", "pair":"EURUSD", "time":"2014.12.31 22:00"}
    string bridge_up = "status|" + IntegerToString(AccountNumber()) + " bridge {\"status\": \"up" +
                                                                           "\", \"pair\": \"" + Symbol() + 
                                                                           "\", \"time\": \"" + TimeToStr(TimeCurrent()) + "\"}";
    if (s_send(speaker, bridge_up) == -1) Print("Error sending message: " + bridge_up);
    else                                  Print("Published message: " + bridge_up);
  }

  return(speaker_connected);
}
