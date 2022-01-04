//+------------------------------------------------------------------+
//|                                                      Stdv1.0.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 2

enum enPrices
  {
   pr_close,      // Close
   pr_open,       // Open
   pr_high,       // High
   pr_low,        // Low
   pr_median,     // Median
   pr_typical,    // Typical
   pr_weighted,   // Weighted
   pr_average,    // Average (high+low+open+close)/4
   pr_medianb,    // Average median body (open+close)/2
   pr_tbiased,    // Trend biased price
   pr_tbiased2,   // Trend biased (extreme) price
   pr_haclose,    // Heiken ashi close
   pr_haopen,     // Heiken ashi open
   pr_hahigh,     // Heiken ashi high
   pr_halow,      // Heiken ashi low
   pr_hamedian,   // Heiken ashi median
   pr_hatypical,  // Heiken ashi typical
   pr_haweighted, // Heiken ashi weighted
   pr_haaverage,  // Heiken ashi average
   pr_hamedianb,  // Heiken ashi median body
   pr_hatbiased,  // Heiken ashi trend biased price
   pr_hatbiased2, // Heiken ashi trend biased (extreme) price
   pr_habclose,   // Heiken ashi (better formula) close
   pr_habopen,    // Heiken ashi (better formula) open
   pr_habhigh,    // Heiken ashi (better formula) high
   pr_hablow,     // Heiken ashi (better formula) low
   pr_habmedian,  // Heiken ashi (better formula) median
   pr_habtypical, // Heiken ashi (better formula) typical
   pr_habweighted,// Heiken ashi (better formula) weighted
   pr_habaverage, // Heiken ashi (better formula) average
   pr_habmedianb, // Heiken ashi (better formula) median body
   pr_habtbiased, // Heiken ashi (better formula) trend biased price
   pr_habtbiased2 // Heiken ashi (better formula) trend biased (extreme) price
  };


extern int HistoryBars = 20;
extern enPrices        Price           = pr_close;  // Price to use
extern int gloPeriod = 10;
extern string globalBars =  "";//Bars reverse (0 = off)






#define pi 3.14
double newDtr = pi / 180;
double a1 = MathExp(-1.414 * pi / gloPeriod);
double b1 = 2 * a1 * MathCos(newDtr * 1.414 * 180 / gloPeriod);
double coef2 = b1;
double coef3 = -a1 * a1 * b1;
double coef1 = 1 - coef2 - coef3;
int periods = 2;

double  ExtLineBuff[], extMain[], prices[];
int BarsReverse = 0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   IndicatorBuffers(5);
   
//---OutPut line
   SetIndexBuffer(0, extMain);
   SetIndexStyle(0, DRAW_NONE, 0, 0, clrBlue);
   SetIndexShift(0,0);

   SetIndexBuffer(1, ExtLineBuff, INDICATOR_DATA);
   SetIndexStyle(1, DRAW_LINE, 0, 3, clrRed);
   SetIndexShift(1,0);

   SetIndexBuffer(2,prices,INDICATOR_CALCULATIONS);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
  BarsReverse = (int)GlobalVariableGet(globalBars);
   int barslimit = HistoryBars;
   if(barslimit + periods + 1 >= Bars)
     {
      barslimit = Bars - periods - 2;
     }
   for(int i = 0; i <= barslimit + periods ; i++)
     {
      prices[i] = iFilter(getPrice(Price,open,close,high,low,i,rates_total),0,periods,i,rates_total,0);
      double x1, x2, x3;
      if(i >= periods)
        {
         x1 = extMain[i - 1 ] * coef2;
         x2 = extMain[i - 2 ] * coef3;
         x3 = prices[i] * coef1;
         extMain[i] = x1 + x2 + x3;
        }
      else
        {
         extMain[i] = prices[i];
        }
     }


   for(int i = barslimit + periods ; i >= 0; i--)
     {
      double x1, x2, x3;

      if(!isBearish_Cont(i, BarsReverse) && !isBullish_Cont(i, BarsReverse) && BarsReverse != 0)
        {
         ExtLineBuff[i] =  ExtLineBuff[i + 1];
         
        }
      else
         if(i <= barslimit)
           {
            x1 = ExtLineBuff[i + 1] * coef2;
            x2 = ExtLineBuff[i + 2] * coef3;
            x3 = extMain[i] * coef1;
            ExtLineBuff[i] = x1 + x2 + x3;
           }
         else
           {
            ExtLineBuff[i] = extMain[i];
           }
     }


//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void vLine(color clrs, int pos)
  {

   ObjectCreate(ChartID(),string(Time[pos]),OBJ_VLINE,0,Time[pos],0);
   ObjectSetInteger(ChartID(),string(Time[pos]),OBJPROP_COLOR,clrs);
  }
#define _prHABF(_prtype) (_prtype>=pr_habclose && _prtype<=pr_habtbiased2)
#define _priceInstances     1
#define _priceInstancesSize 4
double workHa[][_priceInstances * _priceInstancesSize];
double getPrice(int tprice, const double& open[], const double& close[], const double& high[], const double& low[], int i, int bars, int instanceNo = 0)
  {
   if(tprice >= pr_haclose)
     {
      if(ArrayRange(workHa,0) != bars)
         ArrayResize(workHa,bars);
      instanceNo *= _priceInstancesSize;
      int r = bars - i - 1;

      //
      //
      //
      //
      //

      double haOpen  = (r > 0) ? (workHa[r - 1][instanceNo + 2] + workHa[r - 1][instanceNo + 3]) / 2.0 : (open[i] + close[i]) / 2;;
      double haClose = (open[i] + high[i] + low[i] + close[i]) / 4.0;
      if(_prHABF(tprice))
         if(high[i] != low[i])
            haClose = (open[i] + close[i]) / 2.0 + (((close[i] - open[i]) / (high[i] - low[i])) * fabs((close[i] - open[i]) / 2.0));
         else
            haClose = (open[i] + close[i]) / 2.0;
      double haHigh  = fmax(high[i], fmax(haOpen,haClose));
      double haLow   = fmin(low[i], fmin(haOpen,haClose));

      //
      //
      //
      //
      //

      if(haOpen < haClose)
        {
         workHa[r][instanceNo + 0] = haLow;
         workHa[r][instanceNo + 1] = haHigh;
        }
      else
        {
         workHa[r][instanceNo + 0] = haHigh;
         workHa[r][instanceNo + 1] = haLow;
        }
      workHa[r][instanceNo + 2] = haOpen;
      workHa[r][instanceNo + 3] = haClose;
      //
      //
      //
      //
      //

      switch(tprice)
        {
         case pr_haclose:
         case pr_habclose:
            return(haClose);
         case pr_haopen:
         case pr_habopen:
            return(haOpen);
         case pr_hahigh:
         case pr_habhigh:
            return(haHigh);
         case pr_halow:
         case pr_hablow:
            return(haLow);
         case pr_hamedian:
         case pr_habmedian:
            return((haHigh + haLow) / 2.0);
         case pr_hamedianb:
         case pr_habmedianb:
            return((haOpen + haClose) / 2.0);
         case pr_hatypical:
         case pr_habtypical:
            return((haHigh + haLow + haClose) / 3.0);
         case pr_haweighted:
         case pr_habweighted:
            return((haHigh + haLow + haClose + haClose) / 4.0);
         case pr_haaverage:
         case pr_habaverage:
            return((haHigh + haLow + haClose + haOpen) / 4.0);
         case pr_hatbiased:
         case pr_habtbiased:
            if(haClose > haOpen)
               return((haHigh + haClose) / 2.0);
            else
               return((haLow + haClose) / 2.0);
         case pr_hatbiased2:
         case pr_habtbiased2:
            if(haClose > haOpen)
               return(haHigh);
            if(haClose < haOpen)
               return(haLow);
            return(haClose);
        }
     }

//
//
//
//
//

   switch(tprice)
     {
      case pr_close:
         return(close[i]);
      case pr_open:
         return(open[i]);
      case pr_high:
         return(high[i]);
      case pr_low:
         return(low[i]);
      case pr_median:
         return((high[i] + low[i]) / 2.0);
      case pr_medianb:
         return((open[i] + close[i]) / 2.0);
      case pr_typical:
         return((high[i] + low[i] + close[i]) / 3.0);
      case pr_weighted:
         return((high[i] + low[i] + close[i] + close[i]) / 4.0);
      case pr_average:
         return((high[i] + low[i] + close[i] + open[i]) / 4.0);
      case pr_tbiased:
         if(close[i] > open[i])
            return((high[i] + close[i]) / 2.0);
         else
            return((low[i] + close[i]) / 2.0);
      case pr_tbiased2:
         if(close[i] > open[i])
            return(high[i]);
         if(close[i] < open[i])
            return(low[i]);
         return(close[i]);
     }
   return(0);
  }

#define filterInstances 2
double workFil[][filterInstances * 3];

#define _fchange 0
#define _fachang 1
#define _fprice  2

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double iFilter(double tprice, double filter, int period, int i, int bars, int instanceNo = 0)
  {
   if(filter <= 0)
      return(tprice);
   if(ArrayRange(workFil,0) != bars)
      ArrayResize(workFil,bars);
   i = bars - i - 1;
   instanceNo *= 3;

//
//
//
//
//

   workFil[i][instanceNo + _fprice]  = tprice;
   if(i < 1)
      return(tprice);
   workFil[i][instanceNo + _fchange] = fabs(workFil[i][instanceNo + _fprice] - workFil[i - 1][instanceNo + _fprice]);
   workFil[i][instanceNo + _fachang] = workFil[i][instanceNo + _fchange];

   for(int k = 1; k < period && (i - k) >= 0; k++)
      workFil[i][instanceNo + _fachang] += workFil[i - k][instanceNo + _fchange];
   workFil[i][instanceNo + _fachang] /= period;

   double stddev = 0;
   for(int k = 0;  k < period && (i - k) >= 0; k++)
      stddev += pow(workFil[i - k][instanceNo + _fchange] - workFil[i - k][instanceNo + _fachang],2);
   stddev = sqrt(stddev / (double)period);
   double filtev = filter * stddev;
   if(MathAbs(workFil[i][instanceNo + _fprice] - workFil[i - 1][instanceNo + _fprice]) < filtev)
      workFil[i][instanceNo + _fprice] = workFil[i - 1][instanceNo + _fprice];
   return(workFil[i][instanceNo + _fprice]);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool isBullish(int iShift)
  {
   return (Close[iShift] >= Open[iShift]);
  }

//+------------------------------------------------------------------+
bool isBearish(int iShift)
  {
   return (Close[iShift] < Open[iShift]);
  }

//+------------------------------------------------------------------+
bool isBullish_Cont(int iStar, int iCount)
  {
   for(int i = iStar; i < iStar + iCount; i++)
     {
      if(!isBullish(i))
         return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool isBearish_Cont(int iStar, int iCount)
  {
   for(int i = iStar; i < iStar + iCount; i++)
     {
      if(!isBearish(i))
         return(false);
     }
   return(true);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
