/* Sphere Decoding
  Implements a soft-output Schnorr-Euchner single-tree-search sphere decoding algorithm.
  Details about the algorithm can be found here:
      C. Studer, M. Wenk, A. Burg and H. Bolcskei, "Soft-Output Sphere Decoding: Performance and 
      Implementation Aspects," 2006 Fortieth Asilomar Conference on Signals, Systems and Computers,
      Pacific Grove, CA, 2006, pp. 2071-2076, doi: 10.1109/ACSSC.2006.355132.
    
Author
   - Bashar Tahir, bashar.tahir@tuwien.ac.at
     (c) 2020 Institute of Telecommunications, TU Wien.
     www.nt.tuwien.ac.at 
*/

#include "mex.h"
#include "math.h"
#include <string.h>

double **symbolMapsr, **symbolMapsi, **bitTables;
mwSize nRx, nTx, nTotalBits;
double lambda_ML;
double *lambda_b_MLc, *b_initial;
int *b_ML;
double *nSymbolsPerLayer, *nBitsPerSymbol;
double *yr, *yi, *Rr, *Ri;

void traverseTree(int lvl, double d_prev, double *sr, double *si, int *b, int currBitPos);
double calcMetric(int r, double *xr, double *xi);


void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{    
// Read inputs
    yr                 = mxGetPr(prhs[0]);
    yi                 = mxGetPi(prhs[0]);
    Rr                 = mxGetPr(prhs[1]);
    Ri                 = mxGetPi(prhs[1]);
    nRx                = mxGetScalar(mxGetCell(prhs[4], 0));
    nTx                = mxGetScalar(mxGetCell(prhs[4], 1));
    nTotalBits         = mxGetScalar(mxGetCell(prhs[4], 2));
    nSymbolsPerLayer   = mxGetPr(mxGetCell(prhs[4], 3));
    nBitsPerSymbol     = mxGetPr(mxGetCell(prhs[4], 4));
    lambda_ML          = mxGetScalar(mxGetCell(prhs[4], 5));
    b_initial          = mxGetPr(mxGetCell(prhs[4], 6));
    symbolMapsr        = new double *[nTx];
    symbolMapsi        = new double *[nTx];
    bitTables          = new double *[nTx]; 
    for (int i = 0; i < nTx; i++) {
        symbolMapsr[i] = mxGetPr(mxGetCell(prhs[2], i));
        symbolMapsi[i] = mxGetPi(mxGetCell(prhs[2], i));
        bitTables[i]   = mxGetPr(mxGetCell(prhs[3], i));
    }
    
// Initialize vectors
    double sr [nTx];
    double si [nTx];
    for (int i = 0; i < nTx; i++) {
        sr[i] = 0;
        si[i] = 0;
    }
    lambda_b_MLc = new double [nTotalBits];
    b_ML = new int [nTotalBits];
    int b [nTotalBits];
    for (int i = 0; i < nTotalBits; i++) {
        b[i]            = 0;
        b_ML[i]         = b_initial[i];
        lambda_b_MLc[i] = pow(10, 50);
    }
       
// Sphere decoding 
    traverseTree(1, 0, sr, si, b, 0);
    
// Produce output
    plhs[0] = mxCreateDoubleMatrix(1, nTotalBits, mxREAL);
    plhs[1] = mxCreateDoubleMatrix(1, nTotalBits, mxREAL);
    plhs[2] = mxCreateDoubleMatrix(1, 1, mxREAL);
    double *out1 = mxGetPr(plhs[0]);
    double *out2 = mxGetPr(plhs[1]);
    double *out3 = mxGetPr(plhs[2]);
    for (int i = 0; i < nTotalBits; i++) {
        out1[i] = b_ML[i];
        out2[i] = lambda_b_MLc[i];
    }
    out3[0] = lambda_ML;
    
// Free memory
    delete[] symbolMapsr;
    delete[] symbolMapsi;
    delete[] bitTables;   
    delete[] b_ML;   
}

void traverseTree(int lvl, double d_prev, double *sr, double *si, int *b, int currBitPos)
{
    int currIdx    = nTx - lvl;
    int nSymbols   = nSymbolsPerLayer[currIdx];
    int nBits      = nBitsPerSymbol[currIdx];
    int currPosRev = nTotalBits - (currBitPos + nBits);
    int k, iSB, iB;
    double d;
    
    for (iSB = 0; iSB < nSymbols; iSB++) {
        sr[currIdx] = symbolMapsr[currIdx][iSB];
        si[currIdx] = symbolMapsi[currIdx][iSB];
        d = d_prev + calcMetric(currIdx, sr, si);
        k = 0;
        for (iB = currPosRev; iB < (nTotalBits - currBitPos); iB++) { 
            b[iB] = bitTables[currIdx][k*nSymbols+iSB];
            k = k + 1;
        }   
        if (currIdx == 0){
            if (d < lambda_ML){
                for (iB = 0; iB < nTotalBits; iB++) { 
                    if (b_ML[iB] !=  b[iB]){
                        lambda_b_MLc[iB] = lambda_ML;
                        b_ML[iB]         = b[iB];
                    }
                }
                lambda_ML = d;
            }else{
                for (iB = 0; iB < nTotalBits; iB++) { 
                    if (b_ML[iB] !=  b[iB] && d < lambda_b_MLc[iB]){
                        lambda_b_MLc[iB] = d;
                    }
                }
            }
        }else{
            double maxLambda_MLc = -1;
            for (iB = 0; iB < currPosRev; iB++) { 
                maxLambda_MLc = fmax(maxLambda_MLc, lambda_b_MLc[iB]);
            }
            for (iB = currPosRev; iB < nTotalBits; iB++) {
                if (b_ML[iB] !=  b[iB]){
                    maxLambda_MLc = fmax(maxLambda_MLc, lambda_b_MLc[iB]);
                }
            } 
            if (d < maxLambda_MLc){
                traverseTree(lvl + 1, d, sr, si, b, currBitPos + nBits);
            }  
        }
    }
   
}

double calcMetric(int r, double *xr, double *xi){
    double dR = 0, dI = 0;
    for (int c = r; c < nTx; c++) {
        dR = dR + Rr[c*nRx+r]*xr[c] - Ri[c*nRx+r]*xi[c];
        dI = dI + Rr[c*nRx+r]*xi[c] + Ri[c*nRx+r]*xr[c]; 
    }
    return pow(yr[r] - dR, 2) + pow(yi[r] - dI, 2);
}
