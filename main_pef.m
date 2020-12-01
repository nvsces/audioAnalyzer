function [f0,conf] = main_pef(x,fs)

WindowLength=round(fs.*0.052);
OverlapLength=round(fs*(0.052-0.01));
Range=[50,400];
SamplesPerChannel=size(x,1);
NumChannels=size(x,2);
MedianFilterLength=1;

oneCast=1;
r=size(x,1);
c=size(x,2);

hopLength=WindowLength-OverlapLength;

numHopsFinal = ceil((r-WindowLength)/hopLength) + oneCast;

N = WindowLength;
hopSize = hopLength;
numHops = ceil((r-N)/hopSize) + oneCast;

y = zeros(N,numHops*c);

for channel = 1:c
    for hop = 1:numHops
        temp = x(1+hopSize*(hop-1):min(N+hopSize*(hop-1),r),channel);
        y(1:min(N,numel(temp)),hop+(channel-1)*numHops) = temp;
    end
end


NFFT = 2^nextpow2(2*WindowLength-1);
nCol = size(y,2);

logSpacedFrequency = logspace(1,log10(min(fs/2-1,4000)),NFFT)';
linSpacedFrequency = linspace(0,fs/2,round(NFFT/2)+1)';

wBandEdges = zeros(1,numel(Range));

for i = 1:numel(Range)
    [~,wBandEdges(i)] = min(abs(logSpacedFrequency-Range(i)));
end
edge = wBandEdges;

bwTemp = (logSpacedFrequency(3:end) - logSpacedFrequency(1:end-2))/2;
bw = [bwTemp(1);bwTemp;bwTemp(end)]./NFFT;

freq=logSpacedFrequency';

K     = 10;
gamma = 1.8;
num   = round(numel(freq)/2);
q     = logspace(log10(0.5),log10(K+0.5),num);
h     = 1./(gamma - cos(2*pi*q));

delta = diff([q(1),(q(1:end-1)+q(2:end))./2,q(end)]);
beta  = sum(h.*delta)/sum(delta);

aFilt   = (h - beta)';
numToPad = find(q<1,1,'last');

win = hamming(size(y,1),'periodic');
yw = y.*repmat(win,1,size(y,2));

Y      = fft(yw,NFFT);
Yhalf  = Y(1:(NFFT/2)+1,1:nCol);
Ypower = real(Yhalf.*conj(Yhalf));

Ylog   = interp1(linSpacedFrequency,Ypower,logSpacedFrequency);

Ylog = Ylog.*repmat(bw,1,nCol);

Z   = [zeros(numToPad(1),size(Ylog,2));Ylog];

m   = max(size(Z,1),size(aFilt,1));
mxl = min(edge(end),m - 1);
m2  = min(2^nextpow2(2*m - 1), NFFT*4);

X   = fft(Z,m2,1);
Y   = fft(aFilt,m2,1);
c1  = real(ifft(X.*repmat(conj(Y),1,size(X,2)),[],1));
R   = [c1(m2 - mxl + (1:mxl),:); c1(1:mxl+1,:)];
domain = R(edge(end)+1:end,:);

numCandidates=1;
peakDistance=1;

numCol = size(domain,2);
locs   = zeros(numCol,numCandidates);
peaks  = zeros(numCol,numCandidates);
lower  = edge(1);
upper  = edge(end);

for c = 1:numCol
    for b = 1:numCandidates
        [tempPeak,tempLoc] = max( domain(lower:upper,c) );
        
        idxToRemove = max(tempLoc - peakDistance + lower,lower):min(tempLoc + peakDistance + lower,upper);
        domain(idxToRemove,c) = nan;
        
        locs(c,b) = lower + tempLoc - 1;
        peaks(c,b) = tempPeak;
    end
end

f0 = logSpacedFrequency(locs);
peaks(peaks<0) = 0;
conf = peaks./sum(peaks,2);

end
