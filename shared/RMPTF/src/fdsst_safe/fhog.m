function H = fhog(image, binSize, nOrients, clipValue, crop)
%FHOG 纯 MATLAB 稠密 HOG 兼容层，输出 fDSST 所需 3*nOrients+5 通道。
% 它保持尺寸/通道语义，不追求旧 Piotr MEX 的逐位一致性。
if nargin<2, binSize=8; end
if nargin<3, nOrients=9; end
if nargin<4, clipValue=.2; end
if nargin<5, crop=false; end
image=single(image); if ndims(image)==3, image=rgb2gray(image); end
[gx,gy]=gradient(image); magnitude=hypot(gx,gy); angleValue=mod(atan2(gy,gx),2*pi);
cellH=floor(size(image,1)/binSize); cellW=floor(size(image,2)/binSize);
H=zeros(cellH,cellW,3*nOrients+5,'single');
for row=1:cellH
    rr=(row-1)*binSize+(1:binSize);
    for column=1:cellW
        cc=(column-1)*binSize+(1:binSize); m=magnitude(rr,cc); a=angleValue(rr,cc);
        signed=zeros(1,2*nOrients,'single'); unsigned=zeros(1,nOrients,'single');
        signedIndex=mod(floor(a/(2*pi)*(2*nOrients)),2*nOrients)+1;
        unsignedIndex=mod(floor(mod(a,pi)/pi*nOrients),nOrients)+1;
        for q=1:numel(m)
            signed(signedIndex(q))=signed(signedIndex(q))+m(q);
            unsigned(unsignedIndex(q))=unsigned(unsignedIndex(q))+m(q);
        end
        normValue=sqrt(sum(unsigned.^2)+1e-6);
        signed=min(signed/normValue,clipValue); unsigned=min(unsigned/normValue,clipValue);
        H(row,column,1:2*nOrients)=signed;
        H(row,column,2*nOrients+(1:nOrients))=unsigned;
        energy=min(clipValue,sum(unsigned)/max(nOrients,1));
        H(row,column,3*nOrients+(1:4))=energy;
    end
end
if crop && cellH>2 && cellW>2, H=H(2:end-1,2:end-1,:); end
end
