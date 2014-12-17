//+------------------------------------------------------------------+
//|                                                     mql4_zmq.mq4 |
//|                             Copyright © 2012-2013, Austen Conrad |
//|                                                                  |
//| FOR ZEROMQ USE NOTES PLEASE REFERENCE:                           |
//|                           http://api.zeromq.org/2-1:_start       |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2012, 2013 Austen Conrad"
#property link      "http://www.mql4zmq.org"

// Runtime options to specify.
extern string ZMQ_transport_protocol = "tcp";
extern string ZMQ_server_address = "192.168.0.5";
extern string ZMQ_inbound_port = "1986";
extern string ZMQ_outbound_port = "1985";
extern bool Wait_for_Message = true;
extern int EMA_long = 180;
extern int EMA_short = 60;
extern int MagicNumber = 11041963;
extern string trade_direction = "short";

// Include the libzmq.dll abstration wrapper.
#include <mql4zmq.mqh>

//+------------------------------------------------------------------+
//| variable definitions                                             |
//+------------------------------------------------------------------+
int speaker, listener, context, i, start_position, end_position, ticket;
string outbound_connection_string, inbound_connection_string, uid, command_string;


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
//----

  int major[1];int minor[1];int patch[1];
  zmq_version(major,minor,patch);
  Print("Using zeromq version " + major[0] + "." + minor[0] + "." + patch[0]);
   
  Print(ping("Hello World"));
   
  Print("NOTE: to use the precompiled libraries you will need to have the Microsoft Visual C++ 2010 Redistributable Package installed. To Download: http://www.microsoft.com/download/en/details.aspx?id=5555");
   
  Print("This is an example bridge.");

  context = zmq_init(1);
  speaker = zmq_socket(context, ZMQ_PUB);
  listener = zmq_socket(context, ZMQ_SUB);
  outbound_connection_string = ZMQ_transport_protocol + "://" + ZMQ_server_address + ":" + ZMQ_outbound_port;
  inbound_connection_string = ZMQ_transport_protocol + "://" + ZMQ_server_address + ":" + ZMQ_inbound_port;
  command_string = "cmd|" + AccountName();
  
  // Subscribe to the command channel (i.e. "cmd").  
  // NOTE: to subscribe to multiple channels call zmq_setsockopt multiple times.
  zmq_setsockopt(listener, ZMQ_SUBSCRIBE, command_string);
 
  if (zmq_connect(speaker, outbound_connection_string) == -1) {
    Print("Error connecting the speaker to the central queue!");
    return(-1);
  }

  if (zmq_connect(listener, inbound_connection_string) == -1) {
    Print("Error connecting the listener to the central queue!");
    return(-1);
  }
   
  // Send Notification that bridge is up.
  // Format: bridge|testaccount UP short EURUSD 1355775144
  string bridge_up = "bridge|" + AccountName() + " UP " + trade_direction + " " + Symbol() + " " + TimeCurrent();
  if (s_send(speaker, bridge_up) == -1)
    Print("Error sending message: " + bridge_up);
  else
    Print("Published message: " + bridge_up);

  Print("Listening for commands on channel: " + command_string); // Output command string.
   
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
  string bridge_down = "bridge|" + AccountName() + " DOWN";
  if(s_send(speaker, bridge_down) == -1)
    Print("Error sending message: " + bridge_down);
  else
    Print("Published message: " + bridge_down);
   
  // Protect against memory leaks on shutdown.
  zmq_close(speaker);
  zmq_close(listener);
  zmq_term(context);

//----
  return(0);
}


//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {

//----
   
  struct trade_settings {
    string ticket_id,	  // Ticket ID  (123456789)
	string magic_number,   // MagicNumber
    string type,	      // Type 
                          // 0 = (MQL4) OP_BUY - buying position,
                          // 1 = (MQL4) OP_SELL - selling position,
                          // 2 = (MQL4) OP_BUYLIMIT - buy limit pending position,
                          // 3 = (MQL4) OP_SELLLIMIT - sell limit pending position,
                          // 4 = (MQL4) OP_BUYSTOP - buy stop pending position,
                          // 5 = (MQL4) OP_SELLSTOP - sell stop pending position.

    string pair;	      // Symbol (EURUSD)
    string open_price;	  // Open Price (1.24)
    string splipage;	  // Max. Abweichung in Prozent (0.03)
    string take_profit;	  // Take Profit (1.255)
    string stop_loss;	  // Stop Loss (1.235)
    string lot_size;	  // Lot Size (0.5)
    string object_type;	  // Object Type
    string window;	      // Window
    string open_time;	  // Open Time
    string close_time;	  // CLose Time
    string close_price;	  // Close Price
    string prediction	  // Prediction
  } settings;
  
  settings = {"", "MagicNumer", "", "", "", "", "", "", "", "", "", "", "", "", ""}; 
  
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
	
  // First Part: Read message, analyse message and execute command
  if (Wait_for_Message) {
    string message = s_recv(listener);
  } else {
    string message = s_recv(listener, ZMQ_NOBLOCK);
  }

  // Trade wireframe for sending to MetaTrader specification:
  //
  // For new trade or order:
  // cmd|[account name]|[uid] set [trade_type] [pair] [open price] [take profit price] [stop loss price] [lot size]
  // ex=> 
  //   cmd|testaccount|fdjksalr38wufsd= set 2 EURUSD 1.25 1.2503 1.2450
  //   
  // For updating a trade:
  // cmd|[account name]|[uid] reset [ticket_id] [take profit price] [stop loss price]
  // ex=> 
  //   cmd|testaccount|fdjksalr38wufsd= reset 43916144 1.2515 1.2502
  //
  // For updating an order:
  // cmd|[account name]|[uid] reset [ticket_id] [take profit price] [stop loss price] [open price]
  // ex=> 
  //   cmd|testaccount|fdjksalr38wufsd= reset 43916144 1.2515 1.2502 1.2507
  //   
  // For closing a trade or order:
  // cmd|[account name]|[uid] unset [ticket_id]
  // ex=> 
  //   cmd|testaccount|fdjksalr38wufsd= unset 43916144
   
  // If new trade operation is requested.
  //
  // NOTE: MQL4's order type numbers are as follows:
  // 0 = (MQL4) OP_BUY - buying position,
  // 1 = (MQL4) OP_SELL - selling position,
  // 2 = (MQL4) OP_BUYLIMIT - buy limit pending position,
  // 3 = (MQL4) OP_SELLLIMIT - sell limit pending position,
  // 4 = (MQL4) OP_BUYSTOP - buy stop pending position,
  // 5 = (MQL4) OP_SELLSTOP - sell stop pending position.
	
  if (message != "") {                                     // Will return NULL if no message was received.
    Print("Received message: " + message);
    message_get_settings(message, settings);               // Determine Message settings

    // cmd currentPair: Ask for current Pair
    if (StringFind(message, "currentPair", 0) != -1) {     // cmd currentPair; If current currency pair is requested.
      if (send_response(uid, Symbol()) == false)           // Send response.
        Print("ERROR occurred sending response!");
    
    // cmd reset: Set new Trade Parameter
    } else if (StringFind(message, "reset", 0) != -1) {    // cmd reset
      bool update_ticket = false;
      if (OrderSelect(StrToInteger(settings.ticket_id), SELECT_BY_TICKET)) { // Select the requested order.
        if (settings.open_price == "") {                     // Since 'open_price' was not received, we know that we're updating a trade.
          update_ticket = OrderModify(OrderTicket(),         // Send the trade modify instructions.
                                      OrderOpenPrice(),      // Since 'open_price' was received, we know that we're updating an order.
                                      NormalizeDouble(StrToDouble(settings.stop_loss), Digits),
                                      NormalizeDouble(StrToDouble(settings.take_profit), Digits), 
                                      0,
                                      Blue);
        } else {
          Print(NormalizeDouble(StrToDouble(settings.open_price), Digits));
          update_ticket = OrderModify(OrderTicket(),         // Send the order modify instructions.
                                      NormalizeDouble(StrToDouble(settings.open_price), Digits),
                                      NormalizeDouble(StrToDouble(settings.stop_loss), Digits),
                                      NormalizeDouble(StrToDouble(settings.take_profit), Digits), 
                                      0, 
                                      Blue);
        }
      }
                  
      if (update_ticket == false) {
        Print("OrderSend/OrderSelect failed with error #",GetLastError());
        return(0);
      } else {
    	if (settings.open_price == "") {
    	  Print("Trade: " + settings.ticket_id + " updated stop loss to: " + settings.stop_loss + " and take profit to: " + settings.take_profit);
        } else {
          Print("Order: " + settings.ticket_id + " updated stop loss to: " + settings.stop_loss + ", take profit to: " + settings.take_profit + ", and open price to: " + settings.open_price);
        }
            
        if (send_response(uid, "Order has been processed.") == false) // Send response.
          Print("ERROR occurred sending response!");
      }
      
    // cmd unset: Close Trade
    } else if (StringFind(message, "unset", 0) != -1) {    // cmd unset
      bool close_ticket  = false;
      if (OrderSelect(StrToInteger(settings.ticket_id), SELECT_BY_TICKET)) { // Select the requested order and send the oder close instructions.
        if (OrderType() == OP_BUY) {
          close_ticket = OrderClose(OrderTicket(), OrderLots(), Bid, 3, Red);
        } else if (OrderType() == OP_SELL) {
          close_ticket = OrderClose(OrderTicket(), OrderLots(), Ask, 3, Red);
        } else if (OrderType() == OP_BUYLIMIT || OrderType() == OP_BUYSTOP || OrderType() == OP_SELLLIMIT || OrderType() == OP_SELLSTOP) {
          close_ticket = OrderDelete(OrderTicket());
        }
      }   
      if (close_ticket == false) {
        Print("OrderSend/OrderSelect failed with error #",GetLastError());
        return(0);
      } else {
        Print("Closed trade: " + ticket_id);
            
        if (send_response(uid, "Order has been processed.") == false) // Send response.
          Print("ERROR occurred sending response!");
      }

    // cmd set: Open Trade
    } else if (StringFind(message, "set", 0) != -1) {      // cmd set
      Print(settings.type + " " + settings.pair + ", Open: " + settings.open_price + ", TP: " + settings.take_profit + ", SL: " + settings.stop_loss + ", Lots: " + settings.lot_size);

      // @@@ Anhand des Aktuellen Preises und settings.slipage entscheiden, ob die Order marktausgefuehrt wird oder
      // als BUYLIMIT/STOPLIMIT oder garnicht. Eventuell kann der 5. Parameter von OrderSend auch verwendet werden
      
      Print(NormalizeDouble(StrToDouble(settings.take_profit), Digits)); // Open trade.
         
      ticket = OrderSend(StringTrimLeft(settings.pair),
                         StrToInteger(settings.type), 
                         NormalizeDouble(StrToDouble(settings.lot_size), Digits),
                         NormalizeDouble(StrToDouble(settings.open_price), Digits),
                         3,
                         NormalizeDouble(StrToDouble(settings.stop_loss), Digits),
                         NormalizeDouble(StrToDouble(settings.take_profit), Digits),
                         NULL,
						 StrToInteger(settings.magicnumber),
                         TimeCurrent() + 3600,
                         Green); 
      if (ticket < 0) {
        Print("OrderSend failed with error #",GetLastError());
        return(0);
      } else { 
        if (send_response(uid, "Order has been processed.") == false) // Send response.
          Print("ERROR occurred sending response!");
      }

    // cmd Draw: Draw Object
    } else if (StringFind(message, "Draw", 0) != -1) {     // cmd Draw; If a new element to be drawen is requested.
      double bar_uid = MathRand()%10001/10000.0;           // Generate UID
            
      // Draw the rectangle object.
      Print("Drawing: ", settings.type, " ", settings.window, " ", settings.open_time, " ", settings.open_price, " ", settings.close_time, " ", settings.close_price, " ", settings.prediction);
      if (!ObjectCreate("bar:" + bar_uid, draw_object_string_to_int(settings.type), StrToInteger(settings.window), StrToInteger(settings.open_time), StrToDouble(settings.open_price), StrToInteger(settings.close_time), StrToDouble(settings.close_price))) {
        Print("error: cannot create object! code #",GetLastError());
        send_response(uid, false);                         // Send response.
      } else {
        // Color the bar based on the predicted direction. If no prediction was sent than the 
        // 'prediction' keyword will still occupy the array element and we need to set to Gray.
        if (settings.prediction == "") {
          ObjectSet("bar:" + bar_uid, OBJPROP_COLOR, Gray);
        } else if (StrToDouble(settings.prediction) > 0.5) {
          ObjectSet("bar:" + bar_uid, OBJPROP_COLOR, CadetBlue);
        } else if (StrToDouble(settings.prediction) < 0.5) {
          ObjectSet("bar:" + bar_uid, OBJPROP_COLOR, IndianRed);
        } else
          ObjectSet("bar:" + bar_uid, OBJPROP_COLOR, Gray);
        send_response(uid, true);                          // Send response.
      }         
    }
    return(0);
  }
   
  // Second Part: Hedge Orders: Set TP/SL
  // @@@ Include OrderManager und Aufruf OrderManager

  // Third Part: Deliver new Tick Info, Account Info, Order Info and EMA Info back
  string current_tick         = "tick|" + AccountName() + " " + Symbol() + " " + Bid + " " + Ask + " " + Time[0]; // Publish current tick value.
  string current_orders       = lookup_open_orders();                                                             // Publish the currently open orders.
  string current_account_info = "account|" + AccountName() + " " + AccountLeverage() + " " + AccountBalance() + " " + AccountMargin() + " " + AccountFreeMargin(); // Publish account info.
  string current_ema_info     = "ema|" + AccountName() + " " + Symbol() + " " + EMA_long + " " + iMA(Symbol(),0,EMA_long,0,MODE_EMA,PRICE_MEDIAN,0) + " " + EMA_short + " " + iMA(Symbol(),0,EMA_short,0,MODE_EMA,PRICE_MEDIAN,0); // Publish currently requested EMA's.
   
  // Publish data.
  //
  // If you need to send a Multi-part message do the following (example is a three part message). 
  //    s_sendmore(speaker, part_1);
  //    s_sendmore(speaker, part_2);
  //    s_send(speaker, part_3);
  //
  if (s_send(speaker, current_tick) == -1)                 // Current tick.
    Print("Error sending message: " + current_tick);
  else
    Print("Published message: " + current_tick);
  if (s_send(speaker, current_orders) == -1)               // Currently open orders.	
    Print("Error sending message: " + current_orders);
  else
    Print("Published message: " + current_orders);   
  if (s_send(speaker, current_account_info) == -1)         // Current account info.	
    Print("Error sending message: " + current_account_info);
  else
    Print("Published message: " + current_account_info );
  if (s_send(speaker, current_ema_info) == -1)             // Current EMA info.	
    Print("Error sending message: " + current_ema_info);
  else
    Print("Published message: " + current_ema_info );
//----
  return(0);
}
  
//+------------------------------------------------------------------+
//| Analyses the messages and collect Ticketparameter
//|      => "cmd|[account name]|[uid] [some command]
//| Returns true if Order could be selected else false    
//+------------------------------------------------------------------+
string message_get_settings(string mymessage, trade_settings settings) {
  bool rc = false;
  
  uid = message_get_uid(mymessage);                    // Pull out request uid. Message is formatted: "cmd|[account name]|[uid] reset [ticket_id] [take profit price] [stop loss price] [optional open price]"
  Print("uid: " + uid);                                // ack uid.
  
  //  cmd|[account name]|[uid] [cmd] {:pair => '[pair]', :type => '[type]', :ticket_id => '[ticket_id]', :open_price => '[open_price]', :take_profit => '[take_profit]', :stop_loss => '[stop_loss]', :open_time => '[open_time]', :expire_time => '[expire_time]', :lots => '[lots]'}
  start_position = StringFind(mymessage, "{", 0) + 1;
  end_position = StringFind(mymessage, "}", start_position + 1);
  
  if (end_position > start_position) {
	mymessage = StringSubstr(mymessage, start_position, end_position - start_position);
	start_position = StringFind(mymessage, ":", 0) + 1;
	end_position   = StringFind(mymessage, " ", start_position + 1);
    if (end_position > start_position) {
	  key = StringSubstr(parameter, start_position, end_position - start_position);
      start_position = StringFind(mymessage, "'", end_position) + 1;
      end_position   = StringFind(mymessage, "'", start_position + 1);
      if (end_position > start_position) {
        value = StringSubstr(mymessage, start_position, end_position - start_position);
        mymessage = StringSubstr(mymessage, end_position);
        // @@@ Hoffentlich klappt das! Gemeint ist bei key=ticket_id und value=1234567  :  settings.ticket_id = 1234567
        settings.key = value;
      }
    }
  }
} 


//+------------------------------------------------------------------+
//| Pulls out the UID for the message. Messages are fomatted:
//|      => "cmd|[account name]|[uid] [some command]
//+------------------------------------------------------------------+
string message_get_uid(string mymessage) {
  string uid_start_string = "cmd|" + AccountName() + "|";  // Pull out request uid. Message is formatted: "cmd|[accountname]|[uid] [some command]"
  int uid_start = StringFind(mymessage, uid_start_string, 0) + StringLen(uid_start_string);
  int uid_end = StringFind(mymessage, " ", 0) - uid_start;
  string uid = StringSubstr(mymessage, uid_start, uid_end);
  return(uid);                                             // Return the UID
} 

//+------------------------------------------------------------------+
//| Returns the currently open orders.
//|      => "orders|testaccount1 {:symbol => 'EURUSD', :type => 'sell', ...}, {... "
//+------------------------------------------------------------------+
string lookup_open_orders() {
  string current_orders = "orders|" + AccountName() + " "; // Initialize the orders string.
  int total_orders = OrdersTotal();                        // Look up the total number of open orders.
    
  for (int position=0; position < total_orders; position++) { // Build a json-like string for each order and add it to eh current_orders return string. 
    if (OrderSelect(position,SELECT_BY_POS)==false) continue;
    current_orders = current_orders + "{:pair => \'" + OrderSymbol() + "\', :type => \'" + OrderType() + "\', :ticket_id => \'" + OrderTicket() + "\', :open_price => \'" + OrderOpenPrice() + "\', :take_profit => \'" + OrderTakeProfit() + "\', :stop_loss => \'" + OrderStopLoss() + "\', :open_time => \'" + OrderOpenTime() + "\', :expire_time => \'" + OrderExpiration() + "\', :lots => \'" + OrderLots() + "\'}\n";
  }
      
  return(current_orders);                                  // Return the completed string.
}

//+------------------------------------------------------------------+
//| Sends a response to a command. Messages are formatted:
//|      => "response|[account name]|[uid] [some command]
//+------------------------------------------------------------------+
bool send_response(string uid, string response) {
  string response_string = "response|" + AccountName() + "|" + uid + " " + response; // Compose response string.

  if (s_send(speaker, response_string) == -1) {            // Send the message.
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
    case 0 : return(0);          break;               //	   Vertical line. Uses time part of first coordinate.
    case 1 : return(1);          break;               //	   Horizontal line. Uses price part of first coordinate.
    case 2 : return(2);          break;               //		Trend line. Uses 2 coordinates.
    case 3 : return(3);          break;               //		Trend by angle. Uses 1 coordinate. To set angle of line use ObjectSet() function.
    case 4 : return(4);          break;               //		Regression. Uses time parts of first two coordinates.
    case 5 : return(5);          break;               //		Channel. Uses 3 coordinates.
    case 6 : return(6);          break;               //		Standard deviation channel. Uses time parts of first two coordinates.
    case 7 : return(7);          break;               //		Gann line. Uses 2 coordinate, but price part of second coordinate ignored.
    case 8 : return(8);          break;               //		Gann fan. Uses 2 coordinate, but price part of second coordinate ignored.
    case 9 : return(9);          break;               //		Gann grid. Uses 2 coordinate, but price part of second coordinate ignored.
    case 10 : return(10);        break;               //		Fibonacci retracement. Uses 2 coordinates.
    case 11 : return(11);        break;               //		Fibonacci time zones. Uses 2 coordinates.
    case 12 : return(12);        break;               //		Fibonacci fan. Uses 2 coordinates.
    case 13 : return(13);        break;               //		Fibonacci arcs. Uses 2 coordinates.
    case 14 : return(14);        break;               //		Fibonacci expansions. Uses 3 coordinates.
    case 15 : return(15);        break;               //		Fibonacci channel. Uses 3 coordinates.
    case 16 : return(16);        break;               //		Rectangle. Uses 2 coordinates.
    case 17 : return(17);        break;               //		Triangle. Uses 3 coordinates.
    case 18 : return(18);        break;               //		Ellipse. Uses 2 coordinates.
    case 19 : return(19);        break;               //		Andrews pitchfork. Uses 3 coordinates.
    case 20 : return(20);        break;               //		Cycles. Uses 2 coordinates.
    case 21 : return(21);        break;               //		Text. Uses 1 coordinate.
    case 22 : return(22);        break;               //		Arrows. Uses 1 coordinate.
    case 23 : return(23);        break;               //	   Labels.
    default : return(-1);                             //     ERROR. NO MATCH FOUND.
  }
}

//+------------------------------------------------------------------+