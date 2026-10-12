function A = readNpy(file)
%READNPY  NumPy-.npy-Datei lesen (ohne Python). Unterstuetzt numerische und boolesche
%   Typen, C- und Fortran-Ordnung, Formatversion 1-3.
%   Format: https://numpy.org/doc/stable/reference/generated/numpy.lib.format.html
    fid = fopen(file, 'r', 'ieee-le');
    if fid < 0, error('mrsim:npy:open', 'Kann %s nicht oeffnen.', file); end
    c = onCleanup(@() fclose(fid));
    magic = fread(fid, 6, 'uint8=>uint8').';
    if ~isequal(magic, uint8([147 'NUMPY']))
        error('mrsim:npy:magic', '%s ist keine .npy-Datei.', file);
    end
    ver = fread(fid, 2, 'uint8');
    if ver(1) == 1
        hlen = fread(fid, 1, 'uint16');
    else
        hlen = fread(fid, 1, 'uint32');
    end
    hdr = fread(fid, hlen, 'uint8=>char').';
    descr = regexp(hdr, '''descr''\s*:\s*''([^'']+)''', 'tokens', 'once');
    fort  = regexp(hdr, '''fortran_order''\s*:\s*(True|False)', 'tokens', 'once');
    shp   = regexp(hdr, '''shape''\s*:\s*\(([^\)]*)\)', 'tokens', 'once');
    if isempty(descr) || isempty(fort) || isempty(shp)
        error('mrsim:npy:header', 'Header nicht lesbar: %s', hdr);
    end
    shape = str2double(regexp(shp{1}, '\d+', 'match'));
    d = descr{1};
    bo = d(1); ty = d(2:end);
    map = {'f4', 'single'; 'f8', 'double'; 'u1', 'uint8'; 'u2', 'uint16'; 'u4', 'uint32'; ...
           'u8', 'uint64'; 'i1', 'int8'; 'i2', 'int16'; 'i4', 'int32'; 'i8', 'int64'; 'b1', 'uint8'};
    k = find(strcmp(map(:, 1), ty), 1);
    if isempty(k)
        warning('mrsim:npy:dtype', 'dtype %s in %s nicht unterstuetzt -> leer.', d, file);
        A = []; return;
    end
    cls = map{k, 2};
    if bo == '>', mf = 'ieee-be'; else, mf = 'ieee-le'; end
    n = prod(shape); if isempty(shape), n = 1; end
    A = fread(fid, n, [cls '=>' cls], 0, mf);
    if strcmp(ty, 'b1'), A = logical(A); end
    if numel(shape) >= 2
        if strcmp(fort{1}, 'True')
            A = reshape(A, shape);
        else
            A = permute(reshape(A, fliplr(shape)), numel(shape):-1:1);
        end
    end
end
