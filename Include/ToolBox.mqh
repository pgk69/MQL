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
  int debugLevel(int level=-1);
  void debug(int level, string message);
  int pipCorrection(int level=-1);
  double indFaktor();
  double calcPips(double Percent, double Value);
  double NormRound(double Value);
  int PeriodToIndex(int period);
  int IndexToPeriod(int index);
#import

#endif