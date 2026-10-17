import Testing
@testable import Seekify

@MainActor @Test func parsesSockseekLog() {
    let r = Runner()
    r.ingest("""
    [cli] Downloading 129 tracks:
    [003] SongJob: searching: Bonobo - Me and You
    [004] SongJob: failed [No search results]: Frank Ocean - Nights
    [003] SongJob: downloading: Bonobo - Me and You: hubberb\\..\\Bonobo\\Distance in Static (2026)\\12 - Me and You.flac
    [005] SongJob: searching: Run–D.M.C. - It's Like That
    [003] SongJob: succeeded: Bonobo - Me and You: hubberb\\..\\Bonobo\\Distance in Static (2026)\\12 - Me and You.flac
    [005] SongJob: on-comp
    """)
    // last line is split mid-chunk, like a pipe read would deliver it
    r.ingest("lete: Run–D.M.C. - It's Like That\n")

    #expect(r.total == 129)
    #expect(r.tracks.map(\.name) == ["Bonobo - Me and You", "Frank Ocean - Nights", "Run–D.M.C. - It's Like That"])
    #expect(r.tracks.map(\.state) == [.done, .failed, .converting])
    #expect(r.tracks[1].detail == "No search results")
    #expect(r.doneCount == 1 && r.failedCount == 1)
}
