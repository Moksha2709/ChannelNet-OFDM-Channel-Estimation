/* Polar Decoder
    
Decoding
   - Successive cancellation (SC) based decoder
      -> List-SC
	  -> CRC-List-SC (external)

Author
   - Bashar Tahir, bashar.tahir@tuwien.ac.at
     (c) 2020 Institute of Telecommunications, TU Wien.
     www.nt.tuwien.ac.at 
*/

#include "mex.h"
#include "math.h"
#include <string.h>

const float null = 98811220033.445911;

mwSize logn, listSize, L, n, codedBlockSize;

double *channelLLRs;
double *frozenSet;

double *decodedBitsL;
float **stagesLLRsL;
float **stagesPSumsL;

void decodeListSC();
double LLRrecListSC(mwSize s, mwSize i);
char calcPSumListSC(mwSize s, mwSize i);

double csgn(double x);
double cmin(double x, double y);

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{                      
    channelLLRs     = mxGetPr(prhs[0]);
    frozenSet       = mxGetPr(prhs[1]);
    codedBlockSize  = mxGetScalar(prhs[2]);
    listSize        = mxGetScalar(prhs[3]);
    n               = mxGetN(prhs[0]);
   
    plhs[0]      = mxCreateDoubleMatrix((mwSize)n+1, listSize, mxREAL);
    decodedBitsL = mxGetPr(plhs[0]);
    decodeListSC();
}

// List successive cancellation
void decodeListSC()  
{
    logn = log2(n);
    double *LLRs;
    double *PMs;
    double *sorted;
    double **pes;
    double temp, median;
    
    mwIndex *remFlagged, i, ii, k;
    mwSize nPaths = 1, currnPaths, rem, sizeStage;
    sizeStage = n*logn*sizeof(float);
    
    stagesLLRsL  = new float *[listSize];
    stagesPSumsL = new float *[listSize];
    LLRs         = new double [listSize];
    PMs          = new double [listSize]; 
    remFlagged   = new mwIndex[listSize];
    sorted       = new double[listSize*2]; 
    pes          = new double *[2];
    pes[0]       = new double [listSize];
    pes[1]       = new double [listSize];
    
    for (L=0; L<listSize; L++){
        stagesLLRsL[L]  = new float [n*logn];
        stagesPSumsL[L] = new float [n*logn];
        for (i=0; i<logn*n; i++){
            stagesLLRsL[L][i]  = null;
            stagesPSumsL[L][i] = null;
        }
        PMs[L] = 0;
        pes[0][L] = 1000000000000;
        pes[1][L] = 1000000000000;
    }
    for (i=0; i<codedBlockSize; i++){
        for (L=0; L<nPaths; L++){
            LLRs[L] = LLRrecListSC(logn, i);
        }  
        if (frozenSet[i] == 1){
            // Frozen
            for (L=0; L<nPaths; L++){
                decodedBitsL[L*(n+1)+i+1] = 0;
                if (LLRs[L] <= 0){
                    PMs[L] = PMs[L] + fabs(LLRs[L]);
                }
            }  
        }else{ 
            // Info
            for (L=0; L<nPaths; L++){
                if (LLRs[L] > 0){
                    pes[0][L] = PMs[L];
                    pes[1][L] = PMs[L] + fabs(LLRs[L]);
                }else{
                    pes[0][L] = PMs[L] + fabs(LLRs[L]);
                    pes[1][L] = PMs[L];
                }
            }  
            if (nPaths < listSize) {   
                currnPaths = nPaths;
                for (L=0; L<currnPaths; L++){
                    // Copy path
                    memcpy(stagesLLRsL[nPaths], stagesLLRsL[L], sizeStage);
                    memcpy(stagesPSumsL[nPaths], stagesPSumsL[L], sizeStage);
                    memcpy(&decodedBitsL[nPaths*(n+1)+1], &decodedBitsL[L*(n+1)+1], codedBlockSize*sizeof(double));   

                    // New
                    decodedBitsL[L*(n+1)+i+1]      = 0;
                    decodedBitsL[nPaths*(n+1)+i+1] = 1;
                    PMs[L]      = pes[0][L];
                    PMs[nPaths] = pes[1][L];  
                    nPaths = nPaths + 1;
                }   
            }else {
                // Calculate the median
                for (L=0; L<listSize; L++){
                    sorted[L]          = pes[0][L];
                    sorted[L+listSize] = pes[1][L];
                }  
                for (ii=0; ii<listSize*2; ii++){
                    for (L=1; L<listSize*2-ii; L++){
                        if (sorted[L-1] > sorted[L]){
                            temp        = sorted[L];
                            sorted[L]   = sorted[L-1];
                            sorted[L-1] = temp;
                        }
                    }
                }
                median = (sorted[listSize] + sorted[listSize-1])/2;
                
                // Determine which paths to remove
                k = 0;
                for (L=0; L<nPaths; L++){
                    if (pes[0][L] > median && pes[1][L] > median){
                        remFlagged[k] = L;
                        k = k + 1;
                    }
                }  
                currnPaths = nPaths;
                k = 0;     
                for (L=0; L<currnPaths; L++){
                    if (pes[0][L] > median && pes[1][L] < median){
                        decodedBitsL[L*(n+1)+i+1] = 1;
                        PMs[L] = pes[1][L];
                    }else if (pes[1][L] > median && pes[0][L] < median){
                        decodedBitsL[L*(n+1)+i+1] = 0;
                        PMs[L] = pes[0][L];
                    }else if (pes[1][L] < median && pes[0][L] < median){
                        // Copy path
                        rem = remFlagged[k];
                        k = k + 1;  
                        memcpy(stagesLLRsL[rem], stagesLLRsL[L], sizeStage);
                        memcpy(stagesPSumsL[rem], stagesPSumsL[L], sizeStage);  
                        memcpy(&decodedBitsL[rem*(n+1)+1], &decodedBitsL[L*(n+1)+1], i*sizeof(double));   
                        
                        // New
                        decodedBitsL[L*(n+1)+i+1]   = 0;
                        decodedBitsL[rem*(n+1)+i+1] = 1;
                        PMs[L]   = pes[0][L];
                        PMs[rem] = pes[1][L];  
                    }
                }                  
            }          
        }
    }
    
    // Pass the path metrics back to MATLAB to determine the best path
    for (L=0; L<nPaths; L++){
        decodedBitsL[L*(n+1)] = PMs[L];
    }
    
    // Free memory
    for (L=0; L<listSize; L++){
        delete[] stagesLLRsL[L];
        delete[] stagesPSumsL[L];
    }
    delete[] stagesLLRsL;
    delete[] stagesPSumsL;
    delete[] LLRs;
    delete[] PMs;
    delete[] remFlagged;
    delete[] sorted;
    delete[] pes[0];
    delete[] pes[1];
    delete[] pes;                
}

double LLRrecListSC(mwSize s, mwSize i)
{
    if (stagesLLRsL[L][logn*i + s - 1] == null){
        double a, b, out;
        
        mwSize powS = 1 << (logn - s);
        if (i % (powS*2) < powS)        
        {
            if (s - 1 == 0){
                a = channelLLRs[i];
                b = channelLLRs[i + powS];
            }else{       
                a = LLRrecListSC(s - 1, i);
                b = LLRrecListSC(s - 1, i + powS);
            }
            out = csgn(a*b)*cmin(fabs(a), fabs(b));  
        }else {
            if (s - 1 == 0){
                a = channelLLRs[i - powS];
                b = channelLLRs[i];
            }else{       
                a = LLRrecListSC(s - 1, i - powS);
                b = LLRrecListSC(s - 1, i);
            }

            out = (1-2*calcPSumListSC(s, i - powS))*a + b;
        }
        stagesLLRsL[L][logn*i + s - 1] = out;  
        return out;
    }else{
        return stagesLLRsL[L][logn*i + s - 1];
    }
}

char calcPSumListSC(mwSize s, mwSize i)
{
    if (stagesPSumsL[L][logn*i + s] == null){
        if (s == logn) {
            return decodedBitsL[L*(n+1)+i+1];
        }else{
            char out;
            mwSize powS = 1 << (logn - s);
            if (i % powS < powS/2){
                out = calcPSumListSC(s + 1, i) ^ calcPSumListSC(s + 1, i+powS/2);
            }else{
                out = calcPSumListSC(s + 1, i);
            }
            stagesPSumsL[L][logn*i + s] = out;
            return out;
        }
    }else{
        return stagesPSumsL[L][logn*i + s];
    } 
}

double cmin(double x, double y){
    if (x >= y){
        return y;
    }else {
        return x;
    }
}

double csgn(double x){
    return (x>0) - (x<0);
}
