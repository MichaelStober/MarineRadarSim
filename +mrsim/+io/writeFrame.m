function files = writeFrame(outDir, name, pixPolar, pixCart, maskPolar, maskCart, snrDb, meta, saveMat)
%WRITEFRAME  Ausgabedateien eines Frames schreiben.
%   <name>_polar.png           n_spokes x n_bins, uint8 0..252 (Zeile = Spoke, Spalte = Bin)
%   <name>_cart.png            kartesisch, uint8 0..252, oben = Bug (Head-up) bzw. Nord
%   <name>_landmask_polar.png  Ground Truth Land (255) / Wasser (0), polar
%   <name>_landmask_cart.png   Ground Truth, kartesisch
%   <name>.mat                 snr_db (single, polar) + meta (optional)
    files.polar = [name '_polar.png'];
    files.cart  = [name '_cart.png'];
    imwrite(pixPolar, fullfile(outDir, files.polar));
    imwrite(pixCart,  fullfile(outDir, files.cart));
    imwrite(uint8(maskPolar) * 255, fullfile(outDir, [name '_landmask_polar.png']));
    imwrite(uint8(maskCart)  * 255, fullfile(outDir, [name '_landmask_cart.png']));
    if saveMat
        s.snr_db = snrDb; s.meta = meta; %#ok<STRNU>
        save(fullfile(outDir, [name '.mat']), '-struct', 's', '-v7');
    end
end
