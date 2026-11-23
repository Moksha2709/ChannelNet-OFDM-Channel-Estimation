/* LDPC Decoding (plus extra functions)
                  
Decoding
   - Layered belief propagation (LBP) based decoder
      -> Layered Sum-Product
      -> Layered Min-Sum
	  -> Layered PWL-Min-Sum (piecewise linear Min-Sum)
 
Additionally, a function for constructing the party check matrix in sparse 
form, and the corresponding edges that are used by the decoder is provided

Author
   - Bashar Tahir, bashar.tahir@tuwien.ac.at
     (c) 2020 Institute of Telecommunications, TU Wien.
     www.nt.tuwien.ac.at 
*/

#include "mex.h"
#include "math.h"

double const INF = 1e10;
mwIndex decodingAlgorithm;
mwSize numCN, ColCN, numVN, ColVN, EHrows, EHcols, numEdges;

mwSize maxRowDeg = 0, maxColDeg = 0;
mwIndex *irs,*jcs;
double *sr;

double aS, bS, cor, tempX, tempY, mode,  Zc;
double *Lj;
double *Lji;
double *cnMat;
double *vnMat;
double *EH;
double *outputVarNodes;

double tanhA(double x);
double atanhA(double x);
double csgn(double x);
double cmin(double x, double y);
double cmax(double x, double y);
double minstar(double x, double y);

void liftCode();
void initializeDecoding(); 
void decodeBP(); 

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{   
//  Modes:
//      0: decoder initialization
//      1: belief propagation decoding
//      2: parity check matrix and edges construction
    
    mode                  = mxGetScalar(prhs[0]);
    if (mode != 2){
        Lj                = mxGetPr(prhs[1]);
        Lji               = mxGetPr(prhs[2]);
        cnMat             = mxGetPr(prhs[3]);
        vnMat             = mxGetPr(prhs[4]);
        numCN             = mxGetScalar(prhs[5]);
        ColCN             = mxGetScalar(prhs[6]);
        numVN             = mxGetScalar(prhs[7]);
        ColVN             = mxGetScalar(prhs[8]);
        decodingAlgorithm = mxGetScalar(prhs[9]);

        plhs[0]        = mxCreateDoubleMatrix(1, (mwSize)numVN, mxREAL);
        outputVarNodes = mxGetPr(plhs[0]);
        if (mode == 0){
            initializeDecoding();
        }else{
            decodeBP();
        }
    } else {
        EH     = mxGetPr(prhs[1]);
        Zc     = (mwSize) mxGetScalar(prhs[2]);
        EHrows = mxGetM((prhs[1]));
        EHcols = mxGetN((prhs[1]));
       
//      Number of edges and maximum row and column degrees
        mwSize jj, ii, numNonZeroEH = 0, rowDeg;
        mwSize *colDeg = new mwSize [(mwSize) EHcols];
        for (ii=0; ii<EHcols; ii++){
            colDeg[ii] = 0;
        }
        for (jj=0; jj<EHrows; jj++){
            rowDeg = 0;
            for (ii=0; ii<EHcols; ii++){
                if (EH[jj+EHrows*ii] != -1){
                	numNonZeroEH = numNonZeroEH + 1;
                    rowDeg       = rowDeg + 1;
                    colDeg[ii]   = colDeg[ii] + 1;
                }
            }
            if (rowDeg > maxRowDeg){
                maxRowDeg = rowDeg;
            }
        }
        for (ii=0; ii<EHcols; ii++){
            if (colDeg[ii] > maxColDeg){
                maxColDeg = colDeg[ii];
            }
        }
        delete[] colDeg;
        
        numEdges = numNonZeroEH*Zc;
        
//      Sparse parity check matrix construction
        plhs[0] = mxCreateSparse((mwSize) EHcols*Zc, (mwSize) EHrows*Zc, (mwSize) numEdges, mxREAL);
        sr      = mxGetPr(plhs[0]);
        irs     = mxGetIr(plhs[0]);
        jcs     = mxGetJc(plhs[0]); 

//      Edges of the Tanner graph
        plhs[1] = mxCreateDoubleMatrix((mwSize) EHrows*Zc, maxRowDeg + 1, mxREAL);
        plhs[2] = mxCreateDoubleMatrix((mwSize) EHcols*Zc, maxColDeg + 1, mxREAL);
        cnMat   = mxGetPr(plhs[1]);
        vnMat   = mxGetPr(plhs[2]);
        
        liftCode();
    }
}

void liftCode()
{
    mwIndex jj, jjIn, ii, k, t = 0, told, p, coli;
    mwSize rows = EHrows*Zc;
    mwSize cols = EHcols*Zc;
    mwSize *counterVN = new mwSize [cols];
    for (ii=0; ii<cols; ii++){
        counterVN[ii] = 0;
    }

    double *rowIndex = new double [(mwSize)numEdges];
    double *colIndex = new double [(mwSize)numEdges];

    for (jj=0; jjIn = (jj+1)*Zc - Zc + 1, jj<EHrows; jj++){
        for (k = 0; k<Zc; k++){
            told = t;
            p    = 0;
            for (ii=0; ii<EHcols; ii++){
                if (EH[jj+EHrows*ii] != -1){
                    rowIndex[t] = jjIn + k;
                    colIndex[t] = k + EH[jj+EHrows*ii];
                    if (colIndex[t] < Zc){
                        colIndex[t] = ii*Zc + colIndex[t] + 1;
                    }else{
                        colIndex[t] = ii*Zc + (colIndex[t] - Zc) + 1;
                    }  
                    irs[t] = colIndex[t] - 1;
                    sr[t] = 1;
                    
                    coli = (mwIndex) colIndex[t] - 1;
                    
                    cnMat[p*rows + jjIn + k - 1]       = coli + 1;
                    vnMat[counterVN[coli]*cols + coli] = rowIndex[t];
                    
                    counterVN[coli] = counterVN[coli] + 1;
                    p               = p + 1;
                    t               = t + 1;
                }
            }
            jcs[jjIn + k - 1] = told;
        }
    }
    jcs[rows] = t;

    delete[] rowIndex;
    delete[] colIndex;
    delete[] counterVN;
}

void initializeDecoding()  
{
    mwIndex ii, jj, teF, ind;
    for (ii=0; ii<numCN; ii++){
        for (jj=0; teF = ii+numCN*jj, ind = cnMat[teF] - 1, ind != -1; jj++){
            Lji[teF] = Lj[ind];
        }
    }
}

// Layered belief propagation decoding
void decodeBP()  
{
    mwIndex startInd, temp, ii, kk, k, jj, jjp1, ii2, jj2, teF;
    double a, b, s, st, c, d;
    double *contVal = new double [ColVN];
    mwIndex *currSel = new mwIndex [ColVN];
   
    switch (decodingAlgorithm){
    // Exact Sum-Product
        case 0:
            for (jj=0; jj<numVN; jj++){
                c = 0;
                k = -1;
                for (ii=0; ii2 = vnMat[jj+numVN*ii] - 1, ii2 != -1; ii++){
                    k = k + 1;
                    b = 1;
                    for (jj2=0; teF = ii2+numCN*jj2, cnMat[teF] != 0; jj2++){
                        if (cnMat[teF] - 1 != jj) {
                            b = b * tanhA(0.5*Lji[teF]);
                        }else{
                            currSel[k] = teF;
                        }
                    }
                    b          = 2*atanhA(b);
                    contVal[k] = b;
                    c          = c + b;     
                }
                outputVarNodes[jj] = Lj[jj] + c;
                
                for (ii=0; ii<=k; ii++){
                    Lji[currSel[ii]] = outputVarNodes[jj] - contVal[ii];
                }     
            }
            break;
            
        // Min-Sum
        case 1:
            for (jj=0; jj<numVN; jj++){
                c = 0;
                k = -1;
                for (ii=0; ii2 = vnMat[jj+numVN*ii] - 1, ii2 != -1; ii++){
                    k = k + 1;
                    b = INF;
                    s = 1;
                    for (jj2=0; teF = ii2+numCN*jj2, cnMat[teF] != 0; jj2++){
                        if (cnMat[teF] - 1 != jj) {
                            b = cmin(b, fabs(Lji[teF]));
                            s = s * csgn(Lji[teF]);
                        }else{
                            currSel[k] = teF;
                        }
                    }
                    b          = s*b;
                    contVal[k] = b;
                    c          = c + b;     
                }
                outputVarNodes[jj] = Lj[jj] + c;
                
                for (ii=0; ii<=k; ii++){
                    Lji[currSel[ii]] = outputVarNodes[jj] - contVal[ii];
                }     
            }
            break;
            
        // PWL-Min-Sum
        case 2:
            for (jj=0; jj<numVN; jj++){
                c = 0;
                k = -1;
                for (ii=0; ii2 = vnMat[jj+numVN*ii] - 1, ii2 != -1; ii++){
                    k = k + 1;
                    b = INF;
                    s = 1;
                    for (jj2=0; teF = ii2+numCN*jj2, cnMat[teF] != 0; jj2++){
                        if (cnMat[teF] - 1 != jj) {
                            b = minstar(b, fabs(Lji[teF]));
                            s = s * csgn(Lji[teF]);
                        }else{
                            currSel[k] = teF;
                        }
                    }
                    b          = s*b;
                    contVal[k] = b;
                    c          = c + b;     
                }
                outputVarNodes[jj] = Lj[jj] + c;
                
                for (ii=0; ii<=k; ii++){
                    Lji[currSel[ii]] = outputVarNodes[jj] - contVal[ii];
                }     
            }
            break;
    }

    delete[] contVal;
    delete[] currSel;
    
}

double tanhA(double x){
    if (x > 10){
        return 1;
    }else if (x < -10){
        return -1;
    }else{
        return tanh(x);
    }
}

double atanhA(double x){
    if (x > 0.9999999999999999){
        return 18.7;
    }else if (x < -0.9999999999999999){
        return -18.7;
    }else{
        return atanh(x);
    }
}

double cmin(double x, double y){
    if (x >= y){
        return y;
    }else {
        return x;
    }
}

double cmax(double x, double y){
    if (x >= y){
        return x;
    }else {
        return y;
    }
}

double csgn(double x){
    return (x>0) - (x<0);
}

double minstar(double a, double b){
    return cmin(a, b) + cmax(0.6931-0.25*(a+b), 0) - cmax(0.6931-0.25*fabs(a-b), 0);
}
