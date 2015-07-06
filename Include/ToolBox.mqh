//+------------------------------------------------------------------+
//|                                                 OrderManager.mqh |
//|                                      Copyright 2014, Peter Kempf |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Peter Kempf"
#property link      "http://www.mql4.com"
#property strict

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
#define VERSION     "1.0"
//
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
//
//+------------------------------------------------------------------+
//| EX4 includes                                                     |
//+------------------------------------------------------------------+
//#include <stderror.mqh>
//#include <stdlib.mqh>
//
//+------------------------------------------------------------------+
#ifndef __ToolBox_H__
#define __ToolBox_H__

#import "ToolBox.ex4"
  void ToolBox_Init();
  int debugLevel(int level=-1);
  void debug(int level, string message);
  int heartBeat(string file=%EA%_%SYMBOL%.log, string content=%TS4%, bool append=false);
  string expandString(string input);
  int hashIdx2Ticket(int idx);
  int hashTicket2Idx(int ticket);
  void hashInitialize(string name, double& array[], double initValue = 0);
  void hashDump(string name, double &array[]);
  double hash(int ticket, string name, double& array[], double newValue = 0);
  int pipCorrection(int level=-1);
  string d2s(double number);
  string i2s(int number);
  string t2s(datetime number);
  double indFaktor();
  double calcPips(double Percent, double Value, string OS = "");
  double NormRound(double Value);
  int PeriodToIndex(int period);
  int IndexToPeriod(int index);
#import

#endif