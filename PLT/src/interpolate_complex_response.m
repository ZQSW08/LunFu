function response=interpolate_complex_response(complexField,xq,yq)
% INTERPOLATE_COMPLEX_RESPONSE 双线性插值复响应，再取相位；不直接插值 phase angle。
[h,w]=size(complexField); x0=floor(xq); y0=floor(yq); x1=x0+1; y1=y0+1; ax=xq-x0; ay=yq-y0;
x0=min(max(x0,1),w); x1=min(max(x1,1),w); y0=min(max(y0,1),h); y1=min(max(y1,1),h);
z00=complexField(sub2ind([h,w],y0,x0)); z10=complexField(sub2ind([h,w],y0,x1)); z01=complexField(sub2ind([h,w],y1,x0)); z11=complexField(sub2ind([h,w],y1,x1));
response=(1-ay).*((1-ax).*z00+ax.*z10)+ay.*((1-ax).*z01+ax.*z11);
end
