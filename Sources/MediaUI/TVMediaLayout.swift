#if os(tvOS)
import UIKit

/// Native UIKit metrics for Apple TV browsing and playback.
public enum TVMediaLayout {
    // MARK: 타이포그래피
    public enum Typography {
        /// 화면 최상단 메인 헤더 ("LIVE", "MY")
        public static let hero = UIFont.systemFont(ofSize: 64, weight: .bold)
        /// 섹션 헤더 (Explore "인기 카테고리" 등)
        public static let section = UIFont.systemFont(ofSize: 36, weight: .semibold)
        /// 28pt subsection — 가로 캐러셀 섹션 헤더, 빈상태 line1, 에러카드 title 등
        public static let subsection = UIFont.systemFont(ofSize: MediaLayout.subsectionTitleSize, weight: .semibold)
        /// 카테고리/이전 헤더 (← 카테고리명)
        public static let title = UIFont.systemFont(ofSize: MediaLayout.titleSize, weight: .bold)
        /// 큰 카드 제목 (방송 제목)
        public static let cardTitleLarge = UIFont.systemFont(ofSize: MediaLayout.cardTitleSize, weight: .semibold)
        /// 중간 카드 제목 (카테고리명, 방송 제목)
        public static let cardTitle = UIFont.systemFont(ofSize: 22, weight: .semibold)
        /// 일반 본문
        public static let body = UIFont.systemFont(ofSize: 20, weight: .regular)
        public static let metadata = UIFont.systemFont(ofSize: MediaLayout.metadataSize, weight: .regular)
        public static let reading = UIFont.systemFont(ofSize: MediaLayout.readingSize, weight: .regular)
        public static let readingAuthor = UIFont.systemFont(ofSize: MediaLayout.readingSize, weight: .semibold)
        public static let readingLineSpacing = MediaLayout.readingLineSpacing
        /// 헤더 보조 (실시간 인기 카테고리 등)
        public static let subhead = UIFont.systemFont(ofSize: 20, weight: .regular)
        /// 18pt subcaption — 오프라인 BJ 닉네임 / 최근 검색어
        public static let subcaption = UIFont.systemFont(ofSize: 18, weight: .semibold)
        /// 캡션 (BJ 닉네임 등)
        public static let caption = UIFont.systemFont(ofSize: 16, weight: .medium)
        /// 배지 (LIVE / 시청자수) — 16pt bold, 3m 거리 가독성 강화
        public static let badge = UIFont.systemFont(ofSize: MediaLayout.badgeSize, weight: .bold)
        /// 작은 메타정보 (Pre-roll hint 등)
        public static let tiny = UIFont.systemFont(ofSize: 14, weight: .semibold)
    }

    // MARK: 간격 (8pt 기반)
    public enum Spacing {
        public static let xs: CGFloat  = 8
        public static let sm: CGFloat  = 16
        public static let md: CGFloat  = 24
        public static let lg: CGFloat  = 40
        public static let xl: CGFloat  = 64
        public static let xxl: CGFloat = 96
        public static let cardTitleToMetadata: CGFloat = 12
    }

    // MARK: 코너 반경
    public enum Corner {
        public static let card: CGFloat    = 18
        public static let badge: CGFloat   = 6
        public static let button: CGFloat  = 16
        public static let modal: CGFloat   = 24
    }

    // MARK: 레이아웃 토큰 (v2 신규)
    public enum Header {
        public static let actionSize = MediaLayout.headerActionSize
    }

    public enum Layout {
        /// 좌우 콘텐츠 마진 (Spacing.xl과 동일하지만 의미 명시)
        public static let contentSideMargin = MediaLayout.pageInset
        /// 섹션 헤더 높이 (MyVC 등)
        public static let sectionHeaderHeight: CGFloat = 80
        /// 헤더 ↔ 그리드 사이 여백
        public static let gridTopGap: CGFloat = 24
        /// 그리드 상단 inset
        public static let gridTopInset: CGFloat = 32
        /// 그리드 하단 inset
        public static let gridBottomInset = MediaLayout.browseBottomInset
        /// 1080p 화면 너비 (참조용)
        public static let screenWidth: CGFloat = 1920
        /// 1080p 화면 높이
        public static let screenHeight: CGFloat = 1080
        /// 메시지 카드 너비 (LoadingOverlayView 등)
        public static let messageCardWidth: CGFloat = 480
        /// 메시지 카드 높이
        public static let messageCardHeight: CGFloat = 200
        /// statusLabel 좌우 여백 (헤더와 동일선)
        public static let statusSideMargin: CGFloat = 60
    }

    public enum Browse {
        public static let pillFadeWidth: CGFloat = 40
        public static let pillRowHeight: CGFloat = 64
        public static let recentPillMaximumWidth: CGFloat = 320
        public static let thumbnailCorner = MediaLayout.browseArtworkRadius
        public static let profileDiameter = MediaLayout.avatarSize
        public static let mediaColumns = MediaLayout.videoColumnCount
        public static let mediaMetadataHeight = MediaLayout.browseMetadataHeight
        public static let categoryMetadataHeight: CGFloat = 94
        public static let categoryAspect: CGFloat = 300.0 / 401
        public static func mediaWidth(in width: CGFloat, sideInset: CGFloat = Layout.contentSideMargin) -> CGFloat {
            max(1, floor(MediaLayout.browseCardWidth(in: width - 2 * sideInset, columns: mediaColumns)))
        }
        public static func mediaSize(width: CGFloat) -> CGSize {
            CGSize(width: width, height: width / MediaCardMetrics.landscapeAspect + mediaMetadataHeight)
        }
        public static func categorySize(width: CGFloat) -> CGSize {
            CGSize(width: width, height: width / categoryAspect + categoryMetadataHeight)
        }
    }

    // MARK: 카드 사이즈 (1080p 기준)
    public enum CardSize {
        /// 카테고리 카드 — 원본 세로 포스터와 두 줄 제목
        public static let category   = Browse.categorySize(width: 320)
        /// 라이브 방송 카드
        public static let broadcast  = Browse.mediaSize(width: 400)
        /// MY 탭 라이브 방송 카드 — broadcast와 동일 위계
        public static let liveShelf     = broadcast
        /// MY 탭 오프라인 BJ 카드
        public static let offlineProfile  = CGSize(width: 240, height: 220)
        /// Explore 인기 캐러셀 카드 — broadcast 카드와 동일
        public static let featuredBroadcast = broadcast
        /// Explore 인기 카테고리 캐러셀 카드 — 일반 카테고리와 동일
        public static let categoryShelf = category
        /// HOME/Explore 캐러셀용 작은 라이브 카드
        public static let miniLive       = CGSize(width: 320, height: 230)
        /// HOME 추천 BJ 카드 (작은 프로필 카드)
        public static let smallProfile    = CGSize(width: 200, height: 240)
        /// 검색 결과 카드 (LiveBroadcastCell과 동일)
        public static let searchResult   = broadcast
    }

    // MARK: 버튼 인셋 (v2 신규)
    public enum ButtonInsets {
        /// CTA 버튼 (다시 시도, 새로고침, 검색 등) — UIButton.Configuration용
        public static let cta = NSDirectionalEdgeInsets(top: 14, leading: 36, bottom: 14, trailing: 36)
    }
}
#endif
