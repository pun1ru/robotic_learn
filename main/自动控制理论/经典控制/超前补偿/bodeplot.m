s= tf('s');
G=10/(s*(1+0.2*s)*(1+0.05*s));

bodeplot(G);
grid on;