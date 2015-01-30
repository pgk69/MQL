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
//| EX4 imports                                                      |
//+------------------------------------------------------------------+
#include <stderror.mqh>
#include <stdlib.mqh>
//
//+------------------------------------------------------------------+
#ifndef __ToolBox_H__
#define __ToolBox_H__

#import "ToolBox.ex4"
  double indFaktor();
  double calcPips(double Boundary, double Percent, double Pips);
  double NormRound(double Value);
#import

#endif