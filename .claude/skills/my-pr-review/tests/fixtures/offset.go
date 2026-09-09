package point

import "context"

type Service struct {
	repo Repo
}

func (s *Service) Offset(ctx context.Context, in Input) error {
	user, err := s.repo.Find(ctx, in.UserID)
	if err != nil {
		return err
	}
	if user.NewFlag {
		return nil
	}
	return s.repo.Save(ctx, user)
}

var defaultLimit = 10
