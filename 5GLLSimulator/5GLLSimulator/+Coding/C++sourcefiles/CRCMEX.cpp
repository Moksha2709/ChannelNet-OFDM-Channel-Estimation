/* CRC Attachment and Detection

Systematic CRC encoding and detection
                
Author
   - Bashar Tahir, bashar.tahir@tuwien.ac.at
     (c) 2020 Institute of Telecommunications, TU Wien.
     www.nt.tuwien.ac.at 
*/

#include "mex.h"
#include "math.h"

mwSize N, K, P, operation;
double *dataword, *crcPoly, *output;

void crcSystematic();

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{    
    dataword  = mxGetPr(prhs[0]);
    crcPoly   = mxGetPr(prhs[1]);
    operation = mxGetScalar(prhs[2]);
    
    P = mxGetN(prhs[1]);
    
    if (operation == 0){
        K       = mxGetN(prhs[0]);
        plhs[0] = mxCreateDoubleMatrix(1, K + P - 1, mxREAL);
    }else if (operation == 1){
        N       = mxGetN(prhs[0]);
        plhs[0] = mxCreateDoubleMatrix(1, 1, mxREAL);
    }else {
        mexErrMsgIdAndTxt("MI:a", "Incorrect operation. Supported operations are either 0 (CRC attachment), or 1 (CRC detection).");
    }
    output = mxGetPr(plhs[0]);

    crcSystematic();
}

void crcSystematic()  
{
    mwSize P2 = P - 1;
    mwSize k, n, j, p;
    
    if (operation == 0){
        // Systematic CRC encoding
        N = K + P2;
        mwSize *XORed = new mwSize [N];
        
        for (k = 0; k < K; k++){
            XORed[k]  = dataword[k];
            output[k] = dataword[k];
        }
        for (k = K; k < N; k++){
            XORed[k]  = 0;
        }
        for (k = 0; k < K; k++){
            if (XORed[k] % 2 == 1){
                j = 0;
                for (p = k; p <= (k + P2); p++){
                    XORed[p] = XORed[p] + crcPoly[j];
                    j = j + 1;
                }
            }
        }
        for (k = K; k < N; k++){
            output[k] = XORed[k] % 2;
        }
        delete[] XORed; 
        
    }else {
        // Systematic CRC detection
        K = N - P2;
        mwSize *XORed = new mwSize [N];
        
        for (n = 0; n < N; n++){
            XORed[n]  = dataword[n];
        }
        for (k = 0; k < K; k++){
            if (XORed[k] % 2 == 1){
                j = 0;
                for (p = k; p <= (k + P2); p++){
                    XORed[p] = XORed[p] + crcPoly[j];
                    j = j + 1;
                }
            }
        }
        output[0] = 0;
        for (k = K; k < N; k++){
            if (XORed[k] % 2 == 1){
                output[0] = 1;
                break;
            }
        }
        delete[] XORed; 
    }
}

