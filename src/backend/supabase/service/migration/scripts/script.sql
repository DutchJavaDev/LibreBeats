CREATE TABLE IF NOT EXISTS Song (
    Id SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL, --- fixed lenght title
    SourceId VARCHAR(11) NOT NULL, --- youtube video id fixed lenght of 11
    Path VARCHAR(111) NOT NULL, --- for now this is fine
    ThumbnailPath VARCHAR(255) NOT NULL,
    Duration INTEGER NOT NULL,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sourceurl_unique UNIQUE (SourceId),
    CONSTRAINT path_unique UNIQUE (Path),
    CONSTRAINT songsthumbnailpath_unique UNIQUE (ThumbnailPath)
);


-- insert into Song (Name, SourceId, Path, ThumbnailPath, Duration) values
-- ('Sample Song 1', 'dQw4w9WgXcQ', '/music/sample1.mp3', '/thumbnails/sample1.jpg', 213),
-- ('Sample Song 2', 'eY52Zsg-KVI', '/music/sample2.mp3', '/thumbnails/sample2.jpg', 185),
-- ('Sample Song 3', '3JZ_D3ELwOQ', '/music/sample3.mp3', '/thumbnails/sample3.jpg', 240);